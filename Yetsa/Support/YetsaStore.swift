import Foundation
import SwiftData

/// The one store, opened once.
///
/// This exists because an App Intent is not a screen. When Siri runs "add
/// milk to Yetsa" the system may launch the app in the background with no
/// window at all, so the container can no longer be something `YetsaApp`
/// makes on its way to drawing a view — both paths have to arrive at the
/// same `ModelContainer`, or a task added by voice would land in a second
/// store the app never reads.
///
/// `bootstrap()` is kept separate from opening the store on purpose. Seeding
/// and geofencing are things the *app* does when a person opens it; an intent
/// answering "how long until I leave" has no business starting location
/// monitoring.
@MainActor
enum YetsaStore {
    static let shared: ModelContainer = open()

    static var context: ModelContext { shared.mainContext }

    private static func open() -> ModelContainer {
        let schema = Schema([TaskItem.self, Completion.self, DaySchedule.self, WorkPlace.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            fatalError("Could not open the Yetsa store")
        }
        return container
    }

    /// What the app does on launch, and an intent does not.
    static func bootstrap() {
        Seed.installIfNeeded(context)
        ArrivalWatcher.start(in: context)
    }

    // MARK: - Reading, for intents

    /// Everything an intent needs to answer a question about a day, fetched
    /// in one place so no intent has to remember the two fetches and the
    /// calendar that go with them.
    static func plan(for date: Date) -> DayPlan {
        PlanBuilder.plan(
            for: date,
            schedules: fetch(DaySchedule.self),
            tasks: fetch(TaskItem.self),
            calendar: Clock.calendar
        )
    }

    static func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    static func save() {
        try? context.save()
    }
}
