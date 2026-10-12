import Foundation
import SwiftData

/// Named `TaskItem` rather than `Task` so it never collides with Swift
/// concurrency's `Task`.
@Model
final class TaskItem {
    var title: String = ""
    var notes: String = ""
    /// Every task carries an estimate. A task without one cannot be budgeted,
    /// so there is no "unknown" — the default is a quarter of an hour.
    var estimateMinutes: Int = 15
    var contextRaw: String = TaskContext.home.rawValue
    /// Empty means "put it wherever it fits".
    var preferredWindowRaw: String = ""
    var dueDate: Date?
    var createdAt: Date = Date.now
    var isArchived: Bool = false

    var recurrenceRaw: String = RecurrenceKind.once.rawValue
    /// 1 = Sunday … 7 = Saturday. Zero when the recurrence has no weekday.
    var recurrenceWeekday: Int = 0
    /// Weeks for `everyNWeeks`, days for `afterCompletion`.
    var recurrenceInterval: Int = 2
    /// What `everyNWeeks` counts from, so the cadence cannot drift.
    var recurrenceAnchor: Date?
    var quotaPerWeek: Int = 2

    /// Free-text grouping — a cohort, a module, a side project.
    var project: String = ""
    /// A countable pile rather than one task. Zero means it is not a batch.
    var batchTotal: Int = 0
    var batchDone: Int = 0

    var lastCompletedAt: Date?
    /// Part of the ordered get-out-the-door sequence.
    var isMorningRun: Bool = false
    var morningRunOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Completion.task)
    var completions: [Completion] = []

    init(
        title: String,
        estimateMinutes: Int = 15,
        context: TaskContext = .home,
        preferredWindow: WindowKind? = nil,
        recurrence: RecurrenceKind = .once,
        dueDate: Date? = nil,
        notes: String = ""
    ) {
        self.title = title
        self.estimateMinutes = estimateMinutes
        self.contextRaw = context.rawValue
        self.preferredWindowRaw = preferredWindow?.rawValue ?? ""
        self.recurrenceRaw = recurrence.rawValue
        self.dueDate = dueDate
        self.notes = notes
    }

    var context: TaskContext {
        get { TaskContext.stored(contextRaw) }
        set { contextRaw = newValue.rawValue }
    }

    var preferredWindow: WindowKind? {
        get { WindowKind.stored(preferredWindowRaw) }
        set { preferredWindowRaw = newValue?.rawValue ?? "" }
    }

    var recurrence: RecurrenceKind {
        get { RecurrenceKind.stored(recurrenceRaw) }
        set { recurrenceRaw = newValue.rawValue }
    }

    var isBatch: Bool { batchTotal > 0 }

    var batchFraction: Double {
        guard batchTotal > 0 else { return 0 }
        return min(1, Double(batchDone) / Double(batchTotal))
    }

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Real completions only — skips do not count towards a quota.
    var realCompletions: [Completion] {
        completions.filter { !$0.wasSkipped }
    }
}
