import Foundation

/// The get-out-the-door sequence, measured against the door rather than
/// against the clock. `slack` is the whole point: it is the difference between
/// the time you have left and the work you have left, which is the only number
/// worth looking at with a towel in your hand.
struct MorningRun {
    let tasks: [TaskItem]
    let departure: Date
    let day: Date

    private var calendar: Calendar { Clock.calendar }

    var stepCount: Int { tasks.count }

    var doneCount: Int {
        tasks.filter { RecurrenceEngine.isSettled($0, on: day, calendar: calendar) }.count
    }

    var isComplete: Bool { stepCount > 0 && doneCount == stepCount }

    /// Work still ahead of you, in minutes.
    var remainingMinutes: Int {
        tasks.reduce(0) { total, task in
            RecurrenceEngine.isSettled(task, on: day, calendar: calendar)
                ? total
                : total + max(0, task.estimateMinutes)
        }
    }

    var plannedMinutes: Int {
        tasks.reduce(0) { $0 + max(0, $1.estimateMinutes) }
    }

    func minutesToDeparture(from now: Date) -> Int {
        Int(departure.timeIntervalSince(now) / 60)
    }

    /// Positive is spare time, negative is how far behind you are.
    func slack(from now: Date) -> Int {
        minutesToDeparture(from: now) - remainingMinutes
    }

    /// The next thing to actually do.
    var nextStep: TaskItem? {
        tasks.first { !RecurrenceEngine.isSettled($0, on: day, calendar: calendar) }
    }

    func status(from now: Date) -> String {
        if isComplete { return "Ready to go" }
        let spare = slack(from: now)
        if spare < 0 { return "\(Clock.durationString(-spare)) behind" }
        if spare == 0 { return "Exactly on time" }
        return "\(Clock.durationString(spare)) spare"
    }

    static func from(_ plan: DayPlan) -> MorningRun? {
        guard plan.isWorkday, let departure = plan.departure else { return nil }
        let tasks = plan.morningRunTasks
        guard !tasks.isEmpty else { return nil }
        return MorningRun(tasks: tasks, departure: departure.time, day: plan.date)
    }

    /// The next morning still ahead of you. Once today's door has closed this
    /// rolls on to the next working day, so opening the run in the evening
    /// shows tomorrow rather than a countdown that already expired.
    static func upcoming(from now: Date, schedules: [DaySchedule], tasks: [TaskItem]) -> MorningRun? {
        let calendar = Clock.calendar
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let plan = PlanBuilder.plan(for: day, schedules: schedules, tasks: tasks, calendar: calendar)
            guard let run = from(plan), run.departure > now else { continue }
            return run
        }
        return nil
    }

    var isToday: Bool { Clock.calendar.isDateInToday(day) }

    /// How to name the day when it is not this one.
    var dayLabel: String {
        let calendar = Clock.calendar
        if calendar.isDateInToday(day) { return "This morning" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow morning" }
        return day.formatted(.dateTime.weekday(.wide)) + " morning"
    }
}
