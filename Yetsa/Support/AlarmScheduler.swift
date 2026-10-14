import Foundation
import AlarmKit
import SwiftUI

/// What rides along with each alarm, so the app can tell which one fired.
struct YetsaAlarmMetadata: AlarmMetadata {
    var kind: String
}

/// Real alarms, not notifications — AlarmKit alerts sound through silent mode
/// and through a Focus.
///
/// Alarms are grouped by time rather than by day: Monday to Thursday knock off
/// at the same minute, so they share one weekly alarm, and Friday gets its own
/// because it ends half an hour earlier. That keeps the count low, which
/// matters because AlarmKit caps how many an app may hold.
@MainActor
enum AlarmScheduler {

    static var authorizationState: AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    static func requestAuthorization() async -> AlarmManager.AuthorizationState {
        (try? await AlarmManager.shared.requestAuthorization()) ?? .denied
    }

    /// Clears every alarm this app owns and lays them down again from the
    /// scaffold. AlarmManager only ever sees our own, so clearing is safe.
    @discardableResult
    static func reschedule(schedules: [DaySchedule]) async -> Int {
        cancelAll()

        guard authorizationState == .authorized else { return 0 }

        var scheduled = 0
        for kind in AlarmKind.allCases where kind.isEnabled {
            for (minutes, weekdays) in grouped(kind, in: schedules) {
                if await schedule(kind, atMinutes: minutes, on: weekdays) { scheduled += 1 }
            }
        }
        return scheduled
    }

    static func cancelAll() {
        guard let existing = try? AlarmManager.shared.alarms else { return }
        for alarm in existing {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    static var scheduledCount: Int {
        ((try? AlarmManager.shared.alarms) ?? []).count
    }

    // MARK: - Grouping

    /// `[minutes from midnight: the weekdays that share it]` for one kind.
    private static func grouped(_ kind: AlarmKind, in schedules: [DaySchedule]) -> [Int: [Locale.Weekday]] {
        var buckets: [Int: [Locale.Weekday]] = [:]
        for schedule in schedules where kind.applies(to: schedule) {
            guard let weekday = localeWeekday(schedule.weekday) else { continue }
            buckets[kind.minutes(in: schedule), default: []].append(weekday)
        }
        return buckets
    }

    private static func localeWeekday(_ weekday: Int) -> Locale.Weekday? {
        switch weekday {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: nil
        }
    }

    // MARK: - Scheduling

    private static func schedule(
        _ kind: AlarmKind,
        atMinutes minutes: Int,
        on weekdays: [Locale.Weekday]
    ) async -> Bool {
        guard !weekdays.isEmpty else { return false }

        let time = Alarm.Schedule.Relative.Time(hour: minutes / 60, minute: minutes % 60)
        let relative = Alarm.Schedule.Relative(time: time, repeats: .weekly(weekdays))

        let snooze = kind.allowsSnooze
            ? AlarmButton(
                text: "Snooze \(kind.snoozeMinutes) min",
                textColor: .white,
                systemImageName: "zzz"
              )
            : nil

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: kind.label),
            secondaryButton: snooze,
            secondaryButtonBehavior: snooze == nil ? nil : .countdown
        )

        let countdown = kind.allowsSnooze
            ? AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: "Back in \(kind.snoozeMinutes) min"),
                pauseButton: nil
              )
            : nil

        let attributes = AlarmAttributes<YetsaAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: countdown),
            metadata: YetsaAlarmMetadata(kind: kind.rawValue),
            tintColor: .accentColor
        )

        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: kind.allowsSnooze
                ? Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(kind.snoozeMinutes * 60))
                : nil,
            schedule: .relative(relative),
            attributes: attributes,
            sound: .default
        )

        do {
            _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Describing

    /// "05:45 Mon–Fri", or "16:30 Mon–Thu · 16:00 Fri" when a day differs.
    static func summary(_ kind: AlarmKind, schedules: [DaySchedule], calendar: Calendar) -> String {
        var byTime: [Int: [Int]] = [:]
        for schedule in schedules where kind.applies(to: schedule) {
            byTime[kind.minutes(in: schedule), default: []].append(schedule.weekday)
        }
        guard !byTime.isEmpty else { return "No working days set" }

        return byTime
            .sorted { $0.key < $1.key }
            .map { minutes, weekdays in
                "\(Clock.clockString(minutes: minutes, calendar: calendar)) \(dayRange(weekdays))"
            }
            .joined(separator: " · ")
    }

    /// Three or more days in a row collapse to a range; anything else lists.
    private static func dayRange(_ weekdays: [Int]) -> String {
        let order = Weekday.orderedMondayFirst
        var position: [Int: Int] = [:]
        for (index, day) in order.enumerated() { position[day] = index }

        let sorted = weekdays.sorted { (position[$0] ?? 0) < (position[$1] ?? 0) }
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if sorted.count == 1 { return Weekday.shortName(first) }

        let indices = sorted.compactMap { position[$0] }
        let isRun = indices.count == sorted.count
            && zip(indices, indices.dropFirst()).allSatisfy { $1 == $0 + 1 }

        if isRun, sorted.count >= 3 {
            return "\(Weekday.shortName(first))–\(Weekday.shortName(last))"
        }
        return sorted.map(Weekday.shortName).joined(separator: ", ")
    }
}
