import Foundation
import UserNotifications

/// Reminders are anchored to the scaffold, never to a clock time. "Fifteen
/// minutes before you leave" is one rule that already knows Friday ends at
/// four, so nothing needs re-entering when a day is different.
enum NotificationKind: String, CaseIterable, Identifiable, Sendable {
    case morningDigest
    case leavingSoon
    case lunch
    case knockOff
    case eveningPrep
    case weekReview

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morningDigest: "Morning run-through"
        case .leavingSoon: "Leaving in 15 minutes"
        case .lunch: "Lunch break starts"
        case .knockOff: "Knock off"
        case .eveningPrep: "Tomorrow needs"
        case .weekReview: "Friday week review"
        }
    }

    var blurb: String {
        switch self {
        case .morningDigest: "Just after you get out of bed, with the morning's budget."
        case .leavingSoon: "A quarter of an hour before the door, workdays only."
        case .lunch: "Your only weekday window for calls and errands."
        case .knockOff: "Marks the handover from work to your own evening."
        case .eveningPrep: "Ninety minutes before bed — ironing, packing, anything for the morning."
        case .weekReview: "Half an hour before Friday's early knock-off."
        }
    }

    var symbol: String {
        switch self {
        case .morningDigest: "sunrise"
        case .leavingSoon: "figure.walk.departure"
        case .lunch: "fork.knife"
        case .knockOff: "door.left.hand.open"
        case .eveningPrep: "moon.stars"
        case .weekReview: "checklist"
        }
    }

    var defaultsKey: String { "notify.\(rawValue)" }

    /// Whether this one is on. Everything but the review defaults to on.
    var isEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: defaultsKey) == nil { return true }
        return defaults.bool(forKey: defaultsKey)
    }
}

@MainActor
enum NotificationScheduler {
    static let departureLead = 15

    static func requestAuthorization() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        do {
            return try await centre.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Wipes every reminder this app owns and lays them down again from the
    /// current scaffold. Cheap enough to call on any schedule change.
    static func reschedule(schedules: [DaySchedule]) async {
        let centre = UNUserNotificationCenter.current()
        let ours = NotificationKind.allCases.flatMap { kind in
            (1...7).map { "\(kind.rawValue)-\($0)" }
        }
        centre.removePendingNotificationRequests(withIdentifiers: ours)

        guard await authorizationStatus() == .authorized else { return }

        for schedule in schedules {
            for kind in NotificationKind.allCases where kind.isEnabled {
                guard let plan = request(kind, for: schedule) else { continue }
                try? await centre.add(plan)
            }
        }
    }

    private static func request(_ kind: NotificationKind, for schedule: DaySchedule) -> UNNotificationRequest? {
        guard let spec = spec(kind, schedule) else { return nil }

        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.body
        content.sound = .default
        content.threadIdentifier = kind.rawValue

        var components = DateComponents()
        components.weekday = schedule.weekday
        components.hour = spec.minutes / 60
        components.minute = spec.minutes % 60

        return UNNotificationRequest(
            identifier: "\(kind.rawValue)-\(schedule.weekday)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private struct Spec {
        let minutes: Int
        let title: String
        let body: String
    }

    private static func spec(_ kind: NotificationKind, _ schedule: DaySchedule) -> Spec? {
        switch kind {
        case .morningDigest:
            let room = Clock.durationString(schedule.isWorkday ? schedule.morningCapacity : 0)
            return Spec(
                minutes: schedule.outOfBed + 5,
                title: "Morning",
                body: schedule.isWorkday
                    ? "\(room) before you leave. Here is the run-through."
                    : "No work today. Here is what the day is holding."
            )

        case .leavingSoon:
            guard schedule.isWorkday else { return nil }
            return Spec(
                minutes: max(0, schedule.leaveHome - departureLead),
                title: "Leaving in \(departureLead) min",
                body: "Anything still unticked in the morning run?"
            )

        case .lunch:
            guard schedule.isWorkday else { return nil }
            return Spec(
                minutes: schedule.lunch,
                title: "Lunch — \(Clock.durationString(schedule.lunchLength))",
                body: "Today's only window for calls, banking and errands."
            )

        case .knockOff:
            guard schedule.isWorkday else { return nil }
            return Spec(
                minutes: schedule.knockOff,
                title: "Knock off",
                body: "Your evening starts in \(Clock.durationString(schedule.commuteMinutes))."
            )

        case .eveningPrep:
            return Spec(
                minutes: max(0, schedule.bedtime - 105),
                title: "Tomorrow needs",
                body: "Ironing, packing, anything that would cost you the morning."
            )

        case .weekReview:
            // Friday only, half an hour before the early knock-off.
            guard schedule.weekday == 6, schedule.isWorkday else { return nil }
            return Spec(
                minutes: max(0, schedule.knockOff - 30),
                title: "Week review",
                body: "What slipped, and what carries to the weekend?"
            )
        }
    }
}
