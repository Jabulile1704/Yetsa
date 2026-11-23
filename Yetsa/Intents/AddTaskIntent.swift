import AppIntents
import Foundation

/// "Add buy milk to Yetsa."
///
/// Everything except the title has a default, because the whole point of
/// adding by voice is that it takes one breath. An estimate is still required
/// by the model — a task without one cannot be budgeted — so this supplies
/// the same quarter of an hour the app does rather than asking.
struct AddTaskIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Add a Task"

    nonisolated static let description = IntentDescription(
        "Adds a one-off task to Yetsa and drops it into the window that will take it.",
        categoryName: "Tasks",
        resultValueName: "Added Task"
    )

    /// Adding is the one thing worth doing without the app coming to the
    /// front — you are usually mid-sentence with someone else when you
    /// remember it.
    nonisolated static let openAppWhenRun = false

    @Parameter(title: "Task", requestValueDialog: "What should I add?")
    var taskTitle: String

    @Parameter(title: "Minutes", default: 15, inclusiveRange: (1, 600))
    var minutes: Int

    @Parameter(title: "Where it can be done", default: TaskContext.home)
    var context: TaskContext

    @Parameter(title: "Window", description: "Leave empty to let Yetsa place it.")
    var window: WindowKind?

    @Parameter(title: "Due", description: "Leave empty for today.")
    var due: Date?

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) to Yetsa") {
            \.$minutes
            \.$context
            \.$window
            \.$due
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<TaskEntity> {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $taskTitle.needsValueError("What should I add?")
        }

        let task = TaskItem(
            title: trimmed,
            estimateMinutes: max(1, minutes),
            context: context,
            preferredWindow: window,
            recurrence: .once,
            dueDate: due ?? Clock.calendar.startOfDay(for: .now)
        )
        YetsaStore.context.insert(task)
        YetsaStore.save()

        // Where it actually landed, which is not always where it was asked to
        // go — an @errand on a workday has nowhere to be but the evening.
        let plan = YetsaStore.plan(for: task.dueDate ?? .now)
        let landed = plan.windows.first { window in
            window.tasks.contains { $0.persistentModelID == task.persistentModelID }
        }

        return .result(
            value: TaskEntity(task),
            dialog: IntentDialog(stringLiteral: IntentAnswers.added(task, landedIn: landed?.kind))
        )
    }
}
