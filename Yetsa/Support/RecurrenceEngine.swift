import Foundation

/// Decides what is owed on a given day.
///
/// The two cases worth reading closely are `everyNWeeks`, which counts weeks
/// from an anchor date so a skipped Saturday cannot drag the cadence onto
/// another weekday, and `weeklyQuota`, which has no due date at all and is
/// satisfied by a count rather than by a tick on a particular morning.
enum RecurrenceEngine {

    static func isDue(_ task: TaskItem, on day: Date, calendar: Calendar) -> Bool {
        guard !task.isArchived else { return false }
        let weekday = calendar.component(.weekday, from: day)

        switch task.recurrence {
        case .once:
            guard let due = task.dueDate else { return false }
            guard calendar.startOfDay(for: due) <= calendar.startOfDay(for: day) else { return false }
            // An open one-off keeps showing up rather than falling quietly off
            // the back of the list. A settled one shows only on the day it was
            // settled, then stops coming back.
            guard let settled = task.completions.first else { return true }
            return calendar.isDate(settled.forDay, inSameDayAs: day)

        case .daily:
            return true

        case .weekdays:
            return (2...6).contains(weekday)

        case .weekly:
            return weekday == task.recurrenceWeekday

        case .everyNWeeks:
            guard weekday == task.recurrenceWeekday else { return false }
            let interval = max(1, task.recurrenceInterval)
            guard let anchor = task.recurrenceAnchor else { return true }
            let weeks = Clock.weeksBetween(anchor, day, calendar: calendar)
            return weeks >= 0 && weeks % interval == 0

        case .weeklyQuota:
            if isTicked(task, on: day, calendar: calendar) { return true }
            return quotaDone(task, inWeekOf: day, calendar: calendar) < max(1, task.quotaPerWeek)

        case .afterCompletion:
            guard let last = task.lastCompletedAt else { return true }
            let gap = max(1, task.recurrenceInterval)
            guard let next = calendar.date(byAdding: .day, value: gap, to: calendar.startOfDay(for: last)) else { return true }
            return calendar.startOfDay(for: day) >= next || isTicked(task, on: day, calendar: calendar)
        }
    }

    /// Completed *or* skipped on this day — either way it is off the list.
    static func isSettled(_ task: TaskItem, on day: Date, calendar: Calendar) -> Bool {
        entry(for: task, on: day, calendar: calendar) != nil
    }

    /// Genuinely done, not skipped.
    static func isTicked(_ task: TaskItem, on day: Date, calendar: Calendar) -> Bool {
        guard let entry = entry(for: task, on: day, calendar: calendar) else { return false }
        return !entry.wasSkipped
    }

    static func isSkipped(_ task: TaskItem, on day: Date, calendar: Calendar) -> Bool {
        entry(for: task, on: day, calendar: calendar)?.wasSkipped ?? false
    }

    /// A one-off is settled outright, not per day — ticking it on Tuesday
    /// still reads as done when you look on Thursday.
    static func entry(for task: TaskItem, on day: Date, calendar: Calendar) -> Completion? {
        if task.recurrence == .once { return task.completions.first }
        return task.completions.first { calendar.isDate($0.forDay, inSameDayAs: day) }
    }

    // MARK: - Quotas

    static func quotaDone(_ task: TaskItem, inWeekOf day: Date, calendar: Calendar) -> Int {
        let start = Clock.startOfWeek(for: day, calendar: calendar)
        guard let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return 0 }
        return task.realCompletions.filter { $0.forDay >= start && $0.forDay < end }.count
    }

    static func quotaRemaining(_ task: TaskItem, inWeekOf day: Date, calendar: Calendar) -> Int {
        max(0, max(1, task.quotaPerWeek) - quotaDone(task, inWeekOf: day, calendar: calendar))
    }

    // MARK: - Looking ahead

    /// When this comes round again, searching a year out before giving up.
    static func nextDue(_ task: TaskItem, after day: Date, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: day)
        for offset in 1...366 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if isDue(task, on: candidate, calendar: calendar) { return candidate }
        }
        return nil
    }

    /// Plain-language cadence, for routine rows and task detail.
    static func cadence(_ task: TaskItem, calendar: Calendar) -> String {
        switch task.recurrence {
        case .once:
            guard let due = task.dueDate else { return "No date" }
            return due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .daily:
            return "Every day"
        case .weekdays:
            return "Mon to Fri"
        case .weekly:
            return "Every \(Weekday.name(task.recurrenceWeekday))"
        case .everyNWeeks:
            let n = max(1, task.recurrenceInterval)
            let day = Weekday.name(task.recurrenceWeekday)
            return n == 1 ? "Every \(day)" : "Every \(n) weeks, \(day)"
        case .weeklyQuota:
            return "\(max(1, task.quotaPerWeek))× a week"
        case .afterCompletion:
            let n = max(1, task.recurrenceInterval)
            return "\(n) days after the last time"
        }
    }

    // MARK: - Ticking

    /// Marks a task done for a day, or un-marks it if it was already settled.
    /// Toggling back off also rolls `lastCompletedAt` back to whatever the
    /// previous real completion was, so `afterCompletion` tasks do not get
    /// stuck in the future after a mis-tap.
    static func toggle(_ task: TaskItem, on day: Date, calendar: Calendar, minutesTaken: Int = 0) {
        if let existing = entry(for: task, on: day, calendar: calendar) {
            task.completions.removeAll { $0 === existing }
            task.lastCompletedAt = task.realCompletions.map(\.forDay).max()
            return
        }
        let completion = Completion(
            forDay: calendar.startOfDay(for: day),
            actualMinutes: minutesTaken
        )
        completion.task = task
        task.completions.append(completion)
        task.lastCompletedAt = task.realCompletions.map(\.forDay).max()
    }

    /// A deliberate skip. Keeps the cadence, stays out of the quota count.
    static func skip(_ task: TaskItem, on day: Date, calendar: Calendar) {
        if let existing = entry(for: task, on: day, calendar: calendar) {
            task.completions.removeAll { $0 === existing }
        }
        let completion = Completion(forDay: calendar.startOfDay(for: day), wasSkipped: true)
        completion.task = task
        task.completions.append(completion)
        task.lastCompletedAt = task.realCompletions.map(\.forDay).max()
    }

    // MARK: - Estimate honesty

    /// What the task really takes, averaged over measured completions. Returns
    /// `nil` until there is enough evidence to be worth saying out loud.
    static func measuredAverage(_ task: TaskItem, minimumSamples: Int = 3) -> Int? {
        let samples = task.realCompletions.map(\.actualMinutes).filter { $0 > 0 }
        guard samples.count >= minimumSamples else { return nil }
        return Int((Double(samples.reduce(0, +)) / Double(samples.count)).rounded())
    }
}
