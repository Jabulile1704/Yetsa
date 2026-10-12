import Foundation

/// How a task comes back. `everyNWeeks` is anchored to a real date rather than
/// counted in days, so skipping one laundry Saturday does not shift the rhythm
/// onto Sundays. `weeklyQuota` is the odd one out: it has no due date at all,
/// only a count you owe the week — which is how cooking twice a week actually
/// behaves.
enum RecurrenceKind: String, CaseIterable, Identifiable, Sendable {
    case once
    case daily
    case weekdays
    case weekly
    case everyNWeeks
    case weeklyQuota
    case afterCompletion

    var id: String { rawValue }

    var label: String {
        switch self {
        case .once: "One-off"
        case .daily: "Every day"
        case .weekdays: "Weekdays"
        case .weekly: "Weekly"
        case .everyNWeeks: "Every few weeks"
        case .weeklyQuota: "A few times a week"
        case .afterCompletion: "After I last did it"
        }
    }

    var blurb: String {
        switch self {
        case .once: "Happens once, on a date."
        case .daily: "Every single day, weekends included."
        case .weekdays: "Monday to Friday."
        case .weekly: "The same weekday every week."
        case .everyNWeeks: "The same weekday, every second or third week, anchored to a date so it never drifts."
        case .weeklyQuota: "No date — just a number you owe the week. Cook twice, gym three times."
        case .afterCompletion: "Counts forward from the day you last ticked it, not from the calendar."
        }
    }

    var symbol: String {
        switch self {
        case .once: "circle"
        case .daily: "repeat"
        case .weekdays: "briefcase"
        case .weekly: "calendar"
        case .everyNWeeks: "calendar.badge.clock"
        case .weeklyQuota: "chart.bar"
        case .afterCompletion: "arrow.clockwise"
        }
    }

    /// Whether this kind pins to a particular weekday.
    var needsWeekday: Bool {
        self == .weekly || self == .everyNWeeks
    }

    var isRecurring: Bool { self != .once }

    nonisolated static func stored(_ raw: String) -> RecurrenceKind {
        RecurrenceKind(rawValue: raw) ?? .once
    }
}
