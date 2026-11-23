import AppIntents
import Foundation

/// The read-only half. None of these change anything, so none of them bring
/// the app to the front — an answer you have to look at a screen for is not
/// an answer you can use while holding a kettle.

/// "What's free this evening?"
struct FreeTimeIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check Free Time"

    nonisolated static let description = IntentDescription(
        "Says how much of a window is still your own, after everything planned into it.",
        categoryName: "Today"
    )

    nonisolated static let openAppWhenRun = false

    @Parameter(title: "Window", description: "Leave empty for the whole day.")
    var window: WindowKind?

    @Parameter(title: "Day", description: "Leave empty for today.")
    var day: Date?

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Check free time in \(\.$window)") {
            \.$day
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let now = Date.now
        let plan = YetsaStore.plan(for: day ?? now)
        let answer = window.map { IntentAnswers.freeTime(in: $0, plan: plan, now: now) }
            ?? IntentAnswers.freeTimeToday(plan: plan, now: now)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

/// "What's next?" — the next fixed point, not the next task. The scaffold is
/// the thing you are actually measured against.
struct NextAnchorIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check What's Next"

    nonisolated static let description = IntentDescription(
        "Says which fixed point of the day comes next, and how long until it.",
        categoryName: "Today"
    )

    nonisolated static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let now = Date.now
        let answer = IntentAnswers.nextAnchor(plan: YetsaStore.plan(for: now), now: now)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

/// "How long until I leave?" — the door specifically. Asked often enough, and
/// urgently enough, to deserve its own phrase rather than hiding behind
/// whatever happens to be next on the scaffold.
struct TimeUntilLeavingIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check Time Until Leaving"

    nonisolated static let description = IntentDescription(
        "Says how long until you are due out of the door.",
        categoryName: "Today"
    )

    nonisolated static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let now = Date.now
        let answer = IntentAnswers.untilDeparture(plan: YetsaStore.plan(for: now), now: now)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

/// "Am I behind?"
///
/// The one intent that earns its keep on its own. Slack — clock left minus
/// work left — is the number the morning run screen exists to show, and this
/// is that number without having to find the phone, unlock it and read it.
struct MorningRunStatusIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check the Morning Run"

    nonisolated static let description = IntentDescription(
        "Says whether you are ahead or behind on the get-out-the-door sequence.",
        categoryName: "Today"
    )

    nonisolated static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let now = Date.now
        let run = MorningRun.upcoming(
            from: now,
            schedules: YetsaStore.fetch(DaySchedule.self),
            tasks: YetsaStore.fetch(TaskItem.self)
        )
        let answer = IntentAnswers.morningRun(run, now: now)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

/// "What's my quote today?" — the one the morning notification carries, on
/// demand, for when it has already been swiped away.
struct TodaysQuoteIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Get Today's Quote"

    nonisolated static let description = IntentDescription(
        "Reads back the motivational quote Yetsa picked for today.",
        categoryName: "Today"
    )

    nonisolated static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let answer = IntentAnswers.todaysQuote(on: .now)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}
