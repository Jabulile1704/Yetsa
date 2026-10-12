import Foundation

/// Finds the right scaffold for a date and hands back a built plan. Views call
/// this rather than touching `DayPlanner` directly, so a missing schedule can
/// never crash a screen.
enum PlanBuilder {

    static func schedule(for date: Date, in schedules: [DaySchedule], calendar: Calendar) -> DaySchedule {
        let weekday = calendar.component(.weekday, from: date)
        if let match = schedules.first(where: { $0.weekday == weekday }) { return match }
        return DaySchedule(weekday: weekday, isWorkday: (2...6).contains(weekday))
    }

    static func plan(
        for date: Date,
        schedules: [DaySchedule],
        tasks: [TaskItem],
        calendar: Calendar = Clock.calendar
    ) -> DayPlan {
        let schedule = schedule(for: date, in: schedules, calendar: calendar)
        return DayPlanner.plan(for: date, schedule: schedule, tasks: tasks, calendar: calendar)
    }
}
