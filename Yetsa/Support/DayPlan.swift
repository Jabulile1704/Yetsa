import Foundation

/// A fixed point in the day. Everything else is measured against these.
struct DayAnchor: Identifiable, Hashable {
    let id: String
    let label: String
    let symbol: String
    let time: Date
    /// The one anchor the morning is racing towards.
    var isDeparture: Bool = false
}

/// A stretch of day with a capacity and whatever has been dropped into it.
struct DayWindow: Identifiable {
    /// Which day this window belongs to, so completion can be looked up
    /// without assuming the plan is for today.
    let date: Date
    let kind: WindowKind
    let start: Date
    let end: Date
    var tasks: [TaskItem] = []

    var id: String { kind.rawValue }

    var capacityMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }

    /// Everything due here, done or not. This is what eats the window.
    var plannedMinutes: Int {
        tasks.reduce(0) { $0 + max(0, $1.estimateMinutes) }
    }

    /// Still to do.
    var remainingMinutes: Int {
        let calendar = Clock.calendar
        return tasks.reduce(0) { total, task in
            RecurrenceEngine.isSettled(task, on: date, calendar: calendar)
                ? total
                : total + max(0, task.estimateMinutes)
        }
    }

    /// The headline number: what is left of the window once the plan is
    /// subtracted. Negative means the plan does not fit.
    var freeMinutes: Int { capacityMinutes - plannedMinutes }

    var isOverbooked: Bool { plannedMinutes > capacityMinutes }

    var loadFraction: Double {
        guard capacityMinutes > 0 else { return 0 }
        return min(1.6, Double(plannedMinutes) / Double(capacityMinutes))
    }

    var isEmpty: Bool { tasks.isEmpty }

    func isCurrent(_ now: Date) -> Bool { now >= start && now < end }
    func isPast(_ now: Date) -> Bool { now >= end }

    /// Clock time left in the window right now, which is the number that
    /// matters once a window has already started.
    func minutesLeft(from now: Date) -> Int {
        max(0, Int(end.timeIntervalSince(now) / 60))
    }
}

/// Anchors and windows in the order they happen.
enum TimelineEntry: Identifiable {
    case anchor(DayAnchor)
    case window(DayWindow)

    var id: String {
        switch self {
        case .anchor(let anchor): "anchor-\(anchor.id)"
        case .window(let window): "window-\(window.id)"
        }
    }
}

struct DayPlan {
    let date: Date
    let isWorkday: Bool
    let snoozeBufferMinutes: Int
    var anchors: [DayAnchor] = []
    var windows: [DayWindow] = []
    var timeline: [TimelineEntry] = []
    /// Quota tasks owed this week, for the summary strip.
    var quotaTasks: [TaskItem] = []

    var departure: DayAnchor? { anchors.first(where: \.isDeparture) }
    var bedtime: DayAnchor? { anchors.last }

    func window(_ kind: WindowKind) -> DayWindow? {
        windows.first { $0.kind == kind }
    }

    /// Windows that spend your own time, not your employer's.
    var personalWindows: [DayWindow] {
        windows.filter { !$0.kind.isWork }
    }

    func nextAnchor(after now: Date) -> DayAnchor? {
        anchors.first { $0.time > now }
    }

    func currentWindow(_ now: Date) -> DayWindow? {
        windows.first { $0.isCurrent(now) }
    }

    var morningRunTasks: [TaskItem] {
        (window(.morning)?.tasks ?? [])
            .filter(\.isMorningRun)
            .sorted { $0.morningRunOrder < $1.morningRunOrder }
    }

    var totalPlannedMinutes: Int {
        personalWindows.reduce(0) { $0 + $1.plannedMinutes }
    }

    var totalRemainingMinutes: Int {
        personalWindows.reduce(0) { $0 + $1.remainingMinutes }
    }

    var overbookedWindows: [DayWindow] {
        personalWindows.filter(\.isOverbooked)
    }
}

/// Builds the day. The scaffold comes first and tasks are poured into it —
/// never the other way round, which is why the app never has to ask "when?".
enum DayPlanner {

    static func plan(
        for date: Date,
        schedule: DaySchedule,
        tasks: [TaskItem],
        calendar: Calendar
    ) -> DayPlan {
        let at = { (minutes: Int) in Clock.date(on: date, minutes: minutes, calendar: calendar) }

        var anchors: [DayAnchor] = [
            DayAnchor(id: "wake", label: "Alarm", symbol: "alarm", time: at(schedule.wake)),
            DayAnchor(id: "up", label: "Out of bed", symbol: "bed.double", time: at(schedule.outOfBed))
        ]
        var windows: [DayWindow] = []
        var timeline: [TimelineEntry] = [
            .anchor(anchors[0]),
            .anchor(anchors[1])
        ]

        func add(_ window: DayWindow) {
            windows.append(window)
            timeline.append(.window(window))
        }

        func add(_ anchor: DayAnchor) {
            anchors.append(anchor)
            timeline.append(.anchor(anchor))
        }

        if schedule.isWorkday {
            add(DayWindow(date: date, kind: .morning, start: at(schedule.outOfBed), end: at(schedule.leaveHome)))
            add(DayAnchor(id: "leave", label: "Leave home", symbol: "figure.walk.departure",
                          time: at(schedule.leaveHome), isDeparture: true))
            add(DayWindow(date: date, kind: .commuteOut, start: at(schedule.leaveHome), end: at(schedule.arriveWork)))
            add(DayAnchor(id: "arrive", label: "At work", symbol: "building.2", time: at(schedule.arriveWork)))
            add(DayWindow(date: date, kind: .workMorning, start: at(schedule.arriveWork), end: at(schedule.lunch)))
            add(DayAnchor(id: "lunch", label: "Lunch", symbol: "fork.knife", time: at(schedule.lunch)))
            add(DayWindow(date: date, kind: .lunch, start: at(schedule.lunch), end: at(schedule.lunch + schedule.lunchLength)))
            add(DayAnchor(id: "backToWork", label: "Back to it", symbol: "arrow.turn.up.right",
                          time: at(schedule.lunch + schedule.lunchLength)))
            add(DayWindow(date: date, kind: .workAfternoon,
                          start: at(schedule.lunch + schedule.lunchLength),
                          end: at(schedule.knockOff)))
            add(DayAnchor(id: "knockOff", label: "Knock off", symbol: "door.left.hand.open",
                          time: at(schedule.knockOff)))
            add(DayWindow(date: date, kind: .commuteHome, start: at(schedule.knockOff), end: at(schedule.homeAgain)))
            add(DayAnchor(id: "home", label: "Home", symbol: "house", time: at(schedule.homeAgain)))
            add(DayWindow(date: date, kind: .evening, start: at(schedule.homeAgain), end: at(schedule.bedtime)))
        } else {
            add(DayWindow(date: date, kind: .morning, start: at(schedule.outOfBed), end: at(schedule.lunch)))
            add(DayAnchor(id: "lunch", label: "Lunch", symbol: "fork.knife", time: at(schedule.lunch)))
            add(DayWindow(date: date, kind: .afternoon,
                          start: at(schedule.lunch + schedule.lunchLength),
                          end: at(schedule.eveningStarts)))
            add(DayAnchor(id: "eveningStarts", label: "Evening", symbol: "sunset", time: at(schedule.eveningStarts)))
            add(DayWindow(date: date, kind: .evening, start: at(schedule.eveningStarts), end: at(schedule.bedtime)))
        }

        add(DayAnchor(id: "bed", label: "Bed", symbol: "moon.zzz", time: at(schedule.bedtime)))

        let due = tasks.filter { RecurrenceEngine.isDue($0, on: date, calendar: calendar) }
        let assigned = assign(due, to: windows, calendar: calendar, date: date)

        // Rebuild the timeline with the filled-in windows, keeping the order.
        let byKind = Dictionary(uniqueKeysWithValues: assigned.map { ($0.kind, $0) })
        let filledTimeline = timeline.map { entry -> TimelineEntry in
            guard case .window(let window) = entry, let filled = byKind[window.kind] else { return entry }
            return .window(filled)
        }

        let quotas = due
            .filter { $0.recurrence == .weeklyQuota }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        return DayPlan(
            date: date,
            isWorkday: schedule.isWorkday,
            snoozeBufferMinutes: schedule.snoozeBuffer,
            anchors: anchors,
            windows: assigned,
            timeline: filledTimeline,
            quotaTasks: quotas
        )
    }

    /// Each task lands in the window it asked for, or the first one that will
    /// take its context. Anything homeless falls into the evening, which is
    /// the only window with real room in it.
    private static func assign(
        _ tasks: [TaskItem],
        to windows: [DayWindow],
        calendar: Calendar,
        date: Date
    ) -> [DayWindow] {
        var buckets: [WindowKind: [TaskItem]] = [:]
        let available = windows.map(\.kind)
        let fallback: WindowKind = available.contains(.evening) ? .evening : (available.first ?? .evening)

        for task in tasks {
            let target: WindowKind
            if let preferred = task.preferredWindow, available.contains(preferred) {
                target = preferred
            } else if let match = windows.first(where: { $0.kind.accepts(task.context) }) {
                target = match.kind
            } else {
                target = fallback
            }
            buckets[target, default: []].append(task)
        }

        return windows.map { window in
            var filled = window
            filled.tasks = (buckets[window.kind] ?? []).sorted { lhs, rhs in
                let lhsSettled = RecurrenceEngine.isSettled(lhs, on: date, calendar: calendar)
                let rhsSettled = RecurrenceEngine.isSettled(rhs, on: date, calendar: calendar)
                if lhsSettled != rhsSettled { return !lhsSettled }
                if lhs.isMorningRun != rhs.isMorningRun { return lhs.isMorningRun }
                if lhs.isMorningRun, lhs.morningRunOrder != rhs.morningRunOrder {
                    return lhs.morningRunOrder < rhs.morningRunOrder
                }
                return lhs.createdAt < rhs.createdAt
            }
            return filled
        }
    }
}
