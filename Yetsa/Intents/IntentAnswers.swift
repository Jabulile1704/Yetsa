import Foundation

/// Every sentence Siri says, built here and nowhere else.
///
/// An App Intent cannot be unit tested without the intents runtime, so the
/// intents in this folder are deliberately thin: they fetch, they call one
/// function in here, and they hand back the string. All of the thinking —
/// which window, whether it is already over, whether the plan even fits — is
/// in these pure functions, which the test suite can reach.
///
/// The prose is written to be *heard*. Siri reads it aloud, so it avoids
/// anything that only works on a screen: no parentheses, no slashes, no bare
/// numbers that need a column heading to make sense of.
enum IntentAnswers {

    // MARK: - Free time

    /// "What's free this evening?"
    static func freeTime(in kind: WindowKind, plan: DayPlan, now: Date,
                         calendar: Calendar = Clock.calendar) -> String {
        guard let window = plan.window(kind) else {
            let when = plan.spokenDay(relativeTo: now, calendar: calendar)
            return "There is no \(kind.spokenName.lowercased()) window \(when)."
        }

        if window.kind.isWork {
            return "\(window.kind.spokenName.capitalizedFirst) is your employer's time, so Yetsa does not budget it."
        }

        let noun = window.kind.spokenName.lowercased()

        if window.isPast(now), plan.isToday(now, calendar: calendar) {
            let done = window.plannedMinutes - window.remainingMinutes
            guard window.plannedMinutes > 0 else { return "Your \(noun) is over. Nothing was planned in it." }
            return window.remainingMinutes == 0
                ? "Your \(noun) is over, and everything in it got done."
                : "Your \(noun) is over with \(Clock.durationString(window.remainingMinutes)) unfinished. "
                    + "\(Clock.durationString(done)) of it got done."
        }

        if window.isEmpty {
            let capacity = Clock.durationString(window.capacityMinutes)
            guard window.isCurrent(now), plan.isToday(now, calendar: calendar) else {
                return "Your \(noun) is clear. \(capacity) with nothing in it."
            }
            let left = Clock.durationString(window.minutesLeft(from: now))
            return "Your \(noun) is clear — \(left) left of it, nothing planned."
        }

        if window.isOverbooked {
            let over = window.plannedMinutes - window.capacityMinutes
            let planned = Clock.durationString(window.plannedMinutes)
            let capacity = Clock.durationString(window.capacityMinutes)
            return "Your \(noun) is overbooked by \(Clock.durationString(over)). "
                + "\(planned) planned into \(capacity)."
        }

        let free = Clock.durationString(window.freeMinutes)
        let planned = Clock.durationString(window.plannedMinutes)
        let count = window.tasks.count
        let things = count == 1 ? "one thing" : "\(count) things"

        if window.isCurrent(now), plan.isToday(now, calendar: calendar) {
            let left = window.minutesLeft(from: now)
            let remaining = window.remainingMinutes
            let clockLeft = Clock.durationString(left)
            if remaining == 0 {
                return "Your \(noun) is clear for the rest of it — \(clockLeft) left and nothing outstanding."
            }
            let work = Clock.durationString(remaining)
            let slack = left - remaining
            return slack >= 0
                ? "\(clockLeft) left of your \(noun), with \(work) still to do. "
                    + "\(Clock.durationString(slack)) spare."
                : "\(clockLeft) left of your \(noun), but \(work) still to do. "
                    + "That is \(Clock.durationString(-slack)) more than fits."
        }

        return "\(free) free in your \(noun). \(things), \(planned) planned."
    }

    /// "How much free time do I have?" — the whole day, work excluded.
    static func freeTimeToday(plan: DayPlan, now: Date, calendar: Calendar = Clock.calendar) -> String {
        let windows = plan.personalWindows
        guard !windows.isEmpty else {
            return "There is no scaffold for \(plan.spokenDay(relativeTo: now, calendar: calendar))."
        }

        let free = windows.reduce(0) { $0 + max(0, $1.freeMinutes) }
        let planned = plan.totalPlannedMinutes
        let remaining = plan.totalRemainingMinutes
        let over = plan.overbookedWindows

        let when = plan.spokenDay(relativeTo: now, calendar: calendar)
        var answer = planned == 0
            ? "Nothing is planned \(when). \(Clock.durationString(free)) of your own time."
            : "\(Clock.durationString(free)) free \(when), with \(Clock.durationString(remaining)) "
                + "still to do out of \(Clock.durationString(planned)) planned."

        let overshoot = { (window: DayWindow) in window.plannedMinutes - window.capacityMinutes }
        if let worst = over.max(by: { overshoot($0) < overshoot($1) }) {
            let amount = Clock.durationString(overshoot(worst))
            let name = worst.kind.spokenName.lowercased()
            answer += over.count == 1
                ? " Your \(name) is overbooked by \(amount)."
                : " \(over.count) windows are overbooked, your \(name) worst by \(amount)."
        }
        return answer
    }

    // MARK: - The next fixed point

    /// "When do I leave?" and "What's next?"
    static func nextAnchor(plan: DayPlan, now: Date, calendar: Calendar = Clock.calendar) -> String {
        guard plan.isToday(now, calendar: calendar) else {
            guard let first = plan.anchors.first else { return "There is no scaffold for that day." }
            let when = plan.spokenDay(relativeTo: now, calendar: calendar).capitalizedFirst
            return "\(when) starts with \(first.label.lowercased()) at \(Clock.clockString(first.time))."
        }
        guard let next = plan.nextAnchor(after: now) else {
            return "Nothing fixed left today. Bed was the last of it."
        }
        let minutes = Int(next.time.timeIntervalSince(now) / 60)
        guard minutes >= 1 else { return "\(next.label) is now." }
        return "\(next.label) in \(Clock.durationString(minutes)), at \(Clock.clockString(next.time))."
    }

    /// "How long until I leave?" — the door specifically, not whatever is next.
    static func untilDeparture(plan: DayPlan, now: Date, calendar: Calendar = Clock.calendar) -> String {
        guard let departure = plan.departure else {
            guard !plan.isWorkday else { return "There is no departure on the scaffold for that day." }
            let when = plan.spokenDay(relativeTo: now, calendar: calendar).capitalizedFirst
            return "\(when) is not a workday, so there is nowhere to be."
        }
        let minutes = Int(departure.time.timeIntervalSince(now) / 60)
        if minutes < 0 {
            return "You were due out at \(Clock.clockString(departure.time)), \(Clock.durationString(-minutes)) ago."
        }
        if minutes < 1 { return "You are due out of the door now." }
        return "\(Clock.durationString(minutes)) until you leave, at \(Clock.clockString(departure.time))."
    }

    // MARK: - The morning run

    /// "Am I behind?" — the one question worth asking with a towel in hand,
    /// which is why the answer leads with the number and not with a list.
    static func morningRun(_ run: MorningRun?, now: Date) -> String {
        guard let run, run.stepCount > 0 else {
            return "There is no morning run set up. Add some steps to your morning in Yetsa."
        }

        // Slack only means something while the run is live. Measured against
        // tomorrow's door it would report hours of spare time, which is true
        // and useless, so a run that is not today's gets described instead of
        // scored.
        guard run.isToday else {
            return "\(run.dayLabel): \(run.stepCount) steps, "
                + "\(Clock.durationString(run.plannedMinutes)) of work, "
                + "door at \(Clock.clockString(run.departure))."
        }

        if run.isComplete {
            let spare = run.minutesToDeparture(from: now)
            return spare > 0
                ? "All \(run.stepCount) steps done, \(Clock.durationString(spare)) before the door."
                : "All \(run.stepCount) steps done."
        }

        let slack = run.slack(from: now)
        let left = run.stepCount - run.doneCount
        let steps = left == 1 ? "one step left" : "\(left) steps left"
        let work = Clock.durationString(run.remainingMinutes)

        if slack < 0 {
            return "\(Clock.durationString(-slack)) behind. \(steps.capitalizedFirst), \(work) of work, "
                + "and \(Clock.durationString(max(0, run.minutesToDeparture(from: now)))) until the door."
        }
        return "\(Clock.durationString(slack)) spare. \(steps.capitalizedFirst), \(work) of work before the door."
    }

    // MARK: - Confirmations

    static func added(_ task: TaskItem, landedIn window: WindowKind?) -> String {
        var answer = "Added \(task.title), \(Clock.durationString(task.estimateMinutes))"
        if let window { answer += ", in your \(window.spokenName.lowercased())" }
        return answer + "."
    }

    static func ticked(_ title: String, wasAlreadyDone: Bool) -> String {
        wasAlreadyDone ? "\(title) was already done." : "Done — \(title)."
    }

    /// The same line the morning notification carries, so hearing it and
    /// reading it can never disagree.
    static func todaysQuote(on day: Date, calendar: Calendar = Clock.calendar) -> String {
        let quote = Quotes.forDay(day, calendar: calendar)
        return "\(quote.text) — \(quote.author)"
    }

    static func nothingMatched(_ phrase: String) -> String {
        "Nothing in Yetsa matches \(phrase)."
    }
}

// MARK: - Speakable names

extension WindowKind {
    /// Window labels are written for a screen, where "Work — morning" reads
    /// fine. Spoken, the dash is a stumble and "morning at home" is what a
    /// person would actually say.
    var spokenName: String {
        switch self {
        case .morning: "morning"
        case .commuteOut: "commute in"
        case .workMorning: "morning at work"
        case .lunch: "lunch break"
        case .workAfternoon: "afternoon at work"
        case .commuteHome: "commute home"
        case .evening: "evening"
        case .afternoon: "afternoon"
        }
    }
}

extension DayPlan {
    func isToday(_ now: Date, calendar: Calendar = Clock.calendar) -> Bool {
        Clock.isSameDay(date, now, calendar: calendar)
    }

    /// "today", "tomorrow", or "on Saturday" — so a sentence can carry the
    /// day without the caller having to decide how to say it.
    func spokenDay(relativeTo now: Date, calendar: Calendar = Clock.calendar) -> String {
        if isToday(now, calendar: calendar) { return "today" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case 2...6: return "on \(date.formatted(.dateTime.weekday(.wide)))"
        default: return "on \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
        }
    }
}

extension String {
    /// Uppercases only the first character, leaving the rest alone —
    /// `capitalized` would turn "commute in" into "Commute In".
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
