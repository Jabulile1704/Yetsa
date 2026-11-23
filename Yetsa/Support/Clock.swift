import Foundation

/// Calendar and time-of-day helpers. The week starts on Monday, because a week
/// that starts on Sunday puts the cooking day and the laundry day in different
/// weeks from the work that surrounds them.
///
/// Every member is `nonisolated`. The project compiles with `MainActor` as
/// the default isolation, which is right for views and for anything touching
/// the store, but Clock is arithmetic on integers and dates — it holds no
/// state and reaches nothing. Leaving it main-actor-isolated made it
/// unreachable from the nonisolated contexts App Intents requires, for no
/// safety gained.
enum Clock {
    nonisolated static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    /// Turns minutes-from-midnight into a real instant on a given day.
    nonisolated static func date(on day: Date, minutes: Int, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
    }

    nonisolated static func minutesFromMidnight(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    nonisolated static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
    }

    nonisolated static func weeksBetween(_ earlier: Date, _ later: Date, calendar: Calendar) -> Int {
        let a = startOfWeek(for: earlier, calendar: calendar)
        let b = startOfWeek(for: later, calendar: calendar)
        return calendar.dateComponents([.weekOfYear], from: a, to: b).weekOfYear ?? 0
    }

    nonisolated static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// The next occurrence of a weekday at or after `date`, that date included.
    nonisolated static func nextDate(weekday: Int, onOrAfter date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        for offset in 0..<7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if calendar.component(.weekday, from: candidate) == weekday { return candidate }
        }
        return start
    }

    // MARK: - Strings

    /// `345` → `"05:45"`, in the reader's own 12- or 24-hour preference.
    nonisolated static func clockString(minutes: Int, calendar: Calendar) -> String {
        let date = Self.date(on: .now, minutes: minutes, calendar: calendar)
        return date.formatted(date: .omitted, time: .shortened)
    }

    nonisolated static func clockString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// `35` → `"35 min"`, `315` → `"5h 15"`, `120` → `"2h"`.
    nonisolated static func durationString(_ minutes: Int) -> String {
        let value = max(0, minutes)
        if value < 60 { return "\(value) min" }
        let hours = value / 60
        let rest = value % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)"
    }

    /// Compact form for tight rows: `"10m"`, `"1h30"`.
    nonisolated static func shortDuration(_ minutes: Int) -> String {
        let value = max(0, minutes)
        if value < 60 { return "\(value)m" }
        let hours = value / 60
        let rest = value % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h\(rest)"
    }
}
