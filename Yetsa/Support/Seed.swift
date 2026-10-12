import Foundation
import SwiftData

/// First-launch contents: the real scaffold and the routines that already
/// exist in the week, so the app is useful before anything is typed into it.
enum Seed {

    static func installIfNeeded(_ context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<DaySchedule>())
        guard (existing ?? []).isEmpty else { return }

        for schedule in schedules() { context.insert(schedule) }
        for task in routines() { context.insert(task) }
        try? context.save()
    }

    // MARK: - The week

    static func schedules() -> [DaySchedule] {
        Weekday.orderedMondayFirst.map { weekday in
            let isWorkday = (2...6).contains(weekday)
            let schedule = DaySchedule(weekday: weekday, isWorkday: isWorkday)

            if isWorkday {
                schedule.wake = 5 * 60 + 45
                schedule.outOfBed = 6 * 60 + 30
                schedule.leaveHome = 7 * 60 + 30
                schedule.arriveWork = 7 * 60 + 45
                schedule.lunch = 13 * 60
                schedule.lunchLength = 45
                // Friday lets go half an hour earlier.
                schedule.knockOff = weekday == 6 ? 16 * 60 : 16 * 60 + 30
                schedule.eveningStarts = 17 * 60
                schedule.bedtime = 22 * 60 + 15
            } else {
                schedule.wake = 7 * 60
                schedule.outOfBed = 7 * 60 + 30
                schedule.leaveHome = 9 * 60
                schedule.arriveWork = 9 * 60 + 15
                schedule.lunch = 13 * 60
                schedule.lunchLength = 60
                schedule.knockOff = 17 * 60
                schedule.eveningStarts = 17 * 60
                // A later night, but Sunday pulls back for Monday's 05:45.
                schedule.bedtime = weekday == 7 ? 23 * 60 : 22 * 60
            }

            return schedule
        }
    }

    // MARK: - Routines

    static func routines() -> [TaskItem] {
        let calendar = Clock.calendar
        let nextSaturday = Clock.nextDate(weekday: 7, onOrAfter: .now, calendar: calendar)
        let laundrySunday = calendar.date(byAdding: .day, value: 1, to: nextSaturday) ?? nextSaturday
        var items: [TaskItem] = []

        // The get-out-the-door sequence, in the order it actually happens.
        let run: [(String, Int)] = [
            ("Iron today's clothes", 10),
            ("Shower", 15),
            ("Get dressed", 5),
            ("Breakfast", 10),
            ("Pack laptop and charger", 5)
        ]
        for (index, step) in run.enumerated() {
            let task = TaskItem(
                title: step.0,
                estimateMinutes: step.1,
                context: .home,
                preferredWindow: .morning,
                recurrence: .weekdays
            )
            task.isMorningRun = true
            task.morningRunOrder = index
            items.append(task)
        }

        // Evening upkeep.
        items.append(TaskItem(
            title: "Tidy the kitchen",
            estimateMinutes: 10,
            context: .home,
            preferredWindow: .evening,
            recurrence: .daily
        ))

        let layout = TaskItem(
            title: "Set out tomorrow's clothes",
            estimateMinutes: 5,
            context: .home,
            preferredWindow: .evening,
            recurrence: .weekdays,
            notes: "Costs five minutes tonight, buys ten tomorrow morning."
        )
        items.append(layout)

        // Cooking is a count, not a date.
        let cook = TaskItem(
            title: "Cook a proper meal",
            estimateMinutes: 45,
            context: .home,
            preferredWindow: .evening,
            recurrence: .weeklyQuota,
            notes: "Cook enough to carry a few days. Sunday is the natural one."
        )
        cook.quotaPerWeek = 2
        items.append(cook)

        // Laundry: anchored so a skipped Saturday never shifts the rhythm.
        let laundry = TaskItem(
            title: "Laundry",
            estimateMinutes: 90,
            context: .home,
            preferredWindow: .morning,
            recurrence: .everyNWeeks,
            notes: "Wash, then hang out. The ironing pile lands on Sunday."
        )
        laundry.recurrenceWeekday = 7
        laundry.recurrenceInterval = 2
        laundry.recurrenceAnchor = nextSaturday
        items.append(laundry)

        let hangOut = TaskItem(
            title: "Hang out the washing",
            estimateMinutes: 15,
            context: .home,
            preferredWindow: .afternoon,
            recurrence: .everyNWeeks
        )
        hangOut.recurrenceWeekday = 7
        hangOut.recurrenceInterval = 2
        hangOut.recurrenceAnchor = nextSaturday
        items.append(hangOut)

        let ironPile = TaskItem(
            title: "Iron the laundry pile",
            estimateMinutes: 60,
            context: .home,
            preferredWindow: .afternoon,
            recurrence: .everyNWeeks,
            notes: "The spike that follows every wash. Worth its own slot."
        )
        ironPile.recurrenceWeekday = 1
        ironPile.recurrenceInterval = 2
        ironPile.recurrenceAnchor = laundrySunday
        items.append(ironPile)

        let groceries = TaskItem(
            title: "Grocery run",
            estimateMinutes: 60,
            context: .errand,
            preferredWindow: .afternoon,
            recurrence: .weekly,
            notes: "Buy for the cooking days, not for the week in general."
        )
        groceries.recurrenceWeekday = 7
        items.append(groceries)

        // Work.
        let prep = TaskItem(
            title: "Prep tomorrow's session",
            estimateMinutes: 30,
            context: .work,
            preferredWindow: .workAfternoon,
            recurrence: .weekdays,
            notes: "Slides, exercises, environment check, attendance."
        )
        prep.project = "Facilitation"
        items.append(prep)

        let review = TaskItem(
            title: "Week review",
            estimateMinutes: 20,
            context: .work,
            preferredWindow: .workAfternoon,
            recurrence: .weekly,
            notes: "What slipped, what carries to the weekend."
        )
        review.recurrenceWeekday = 6
        review.project = "Facilitation"
        items.append(review)

        let marking = TaskItem(
            title: "Review submissions",
            estimateMinutes: 90,
            context: .work,
            preferredWindow: .workMorning,
            recurrence: .once,
            dueDate: calendar.startOfDay(for: .now),
            notes: "One pile, not twelve tasks. Tick them off as you go."
        )
        marking.project = "Facilitation"
        marking.batchTotal = 12
        items.append(marking)

        // A commute is fifteen minutes you already own.
        let callHome = TaskItem(
            title: "Call home",
            estimateMinutes: 15,
            context: .phone,
            preferredWindow: .commuteHome,
            recurrence: .weeklyQuota
        )
        callHome.quotaPerWeek = 2
        items.append(callHome)

        // Keep creation order stable so windows sort sensibly.
        let base = Date.now
        for (index, task) in items.enumerated() {
            task.createdAt = base.addingTimeInterval(Double(index))
        }

        return items
    }
}
