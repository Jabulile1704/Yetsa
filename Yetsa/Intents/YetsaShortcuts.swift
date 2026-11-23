import AppIntents

/// The phrases that work without anyone setting up a shortcut first.
///
/// Every phrase has to contain `\(.applicationName)`, which is the system's
/// way of making sure an app cannot claim a bare English sentence. "Yetsa" is
/// a Sesotho verb, so the phrases read as instructions rather than as a brand
/// name wedged into a sentence: *ask Yetsa what's free this evening*.
///
/// Several phrasings are given per intent on purpose. The one you reach for
/// at 06:15 with a towel in your hand is not the one you would type.
struct YetsaShortcuts: AppShortcutsProvider {

    nonisolated static var shortcutTileColor: ShortcutTileColor { .grayBlue }

    nonisolated static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MorningRunStatusIntent(),
            phrases: [
                "Am I behind in \(.applicationName)",
                "Ask \(.applicationName) if I am behind",
                "Check my morning run in \(.applicationName)",
                "\(.applicationName) morning run"
            ],
            shortTitle: "Am I behind?",
            systemImageName: "figure.walk.motion"
        )

        AppShortcut(
            intent: TimeUntilLeavingIntent(),
            phrases: [
                "How long until I leave in \(.applicationName)",
                "Ask \(.applicationName) when I leave",
                "When do I leave in \(.applicationName)"
            ],
            shortTitle: "Until the door",
            systemImageName: "figure.walk.departure"
        )

        AppShortcut(
            intent: FreeTimeIntent(),
            phrases: [
                "What's free in \(.applicationName)",
                "Ask \(.applicationName) what's free",
                "Check my free time in \(.applicationName)",
                "How much free time do I have in \(.applicationName)"
            ],
            shortTitle: "What's free",
            systemImageName: "hourglass"
        )

        AppShortcut(
            intent: NextAnchorIntent(),
            phrases: [
                "What's next in \(.applicationName)",
                "Ask \(.applicationName) what's next"
            ],
            shortTitle: "What's next",
            systemImageName: "arrow.forward.to.line"
        )

        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "Add to \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Add a task",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Complete a task in \(.applicationName)",
                "Mark something done in \(.applicationName)",
                "Tick something off in \(.applicationName)"
            ],
            shortTitle: "Complete a task",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: TodaysQuoteIntent(),
            phrases: [
                "What's today's quote in \(.applicationName)",
                "Read my \(.applicationName) quote"
            ],
            shortTitle: "Today's quote",
            systemImageName: "quote.opening"
        )
    }
}
