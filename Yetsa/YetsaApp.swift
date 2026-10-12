import SwiftUI
import SwiftData

@main
struct YetsaApp: App {
    private let container = YetsaApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self, Completion.self, DaySchedule.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            fatalError("Could not open the Yetsa store")
        }

        Seed.installIfNeeded(container.mainContext)
        return container
    }
}
