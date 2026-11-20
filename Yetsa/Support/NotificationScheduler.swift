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
    case dailyQuote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morningDigest: "Morning run-through"
        case .leavingSoon: "Leaving in 15 minutes"
        case .lunch: "Lunch break starts"
        case .knockOff: "Knock off"
        case .eveningPrep: "Tomorrow needs"
        case .weekReview: "Friday week review"
        case .dailyQuote: "Morning quote"
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
        case .dailyQuote: "A line worth reading, as you get out of bed. Every day, weekends included."
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
        case .dailyQuote: "quote.opening"
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

        await rescheduleQuotes(schedules: schedules)
    }

    /// A repeating notification carries the same words forever, so the morning
    /// quote is laid down a fortnight at a time as individual one-shots and
    /// topped up whenever the app is opened.
    ///
    /// Fourteen days keeps the total under iOS's limit of sixty-four pending
    /// notifications: the weekly set already accounts for about thirty.
    static func rescheduleQuotes(schedules: [DaySchedule], days: Int = 14) async {
        let centre = UNUserNotificationCenter.current()
        let pending = await centre.pendingNotificationRequests()
        centre.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(quotePrefix) }
        )

        guard NotificationKind.dailyQuote.isEnabled,
              await authorizationStatus() == .authorized else { return }

        let calendar = Clock.calendar
        let today = calendar.startOfDay(for: .now)

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard let schedule = schedules.first(where: { $0.weekday == weekday }) else { continue }

            let fireAt = Clock.date(on: day, minutes: schedule.outOfBed, calendar: calendar)
            // Today's may already be behind us.
            guard fireAt > .now else { continue }

            let quote = Quotes.forDay(day, calendar: calendar)

            let content = UNMutableNotificationContent()
            content.title = "Good morning"
            content.body = "\u{201C}\(quote.text)\u{201D}\n— \(quote.author)"
            content.sound = nil
            content.threadIdentifier = "quote"

            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = schedule.outOfBed / 60
            parts.minute = schedule.outOfBed % 60

            let request = UNNotificationRequest(
                identifier: "\(quotePrefix)\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            )
            try? await centre.add(request)
        }
    }

    private static let quotePrefix = "quote-"


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

        case .dailyQuote:
            // Scheduled day by day rather than weekly, so the line can change.
            return nil

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
