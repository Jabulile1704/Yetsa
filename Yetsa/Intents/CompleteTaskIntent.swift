import AppIntents
import Foundation

/// "Mark iron my clothes as done."
///
/// The point of this one is the morning run. Ticking a step with wet hands on
/// a phone face-down on the counter is exactly the moment a voice command is
/// worth more than a button, and it is why `TaskEntityQuery` matches on
/// spoken words rather than making you pick from a list.
struct CompleteTaskIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Complete a Task"

    nonisolated static let description = IntentDescription(
        "Ticks a task off for today. Already done tasks are left alone rather than un-ticked.",
        categoryName: "Tasks"
    )

    nonisolated static let openAppWhenRun = false

    @Parameter(title: "Task", requestValueDialog: "Which one?")
    var task: TaskEntity

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$task)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calendar = Clock.calendar
        guard let identifier = TaskToken.identifier(from: task.id),
              let item = YetsaStore.fetch(TaskItem.self).first(where: { $0.persistentModelID == identifier })
        else {
            return .result(dialog: IntentDialog(stringLiteral: IntentAnswers.nothingMatched(task.title)))
        }

        // `toggle` is deliberately not used here. By voice there is no visible
        // state to toggle against, so "mark it done" twice must not quietly
        // undo the first one.
        let already = RecurrenceEngine.isSettled(item, on: .now, calendar: calendar)
        if !already {
            RecurrenceEngine.toggle(item, on: .now, calendar: calendar)
            YetsaStore.save()
        }

        return .result(
            dialog: IntentDialog(stringLiteral: IntentAnswers.ticked(item.title, wasAlreadyDone: already))
        )
    }
}
