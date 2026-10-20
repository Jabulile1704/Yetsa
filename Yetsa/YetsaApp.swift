import SwiftUI
import SwiftData
import UserNotifications

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
        let schema = Schema([TaskItem.self, Completion.self, DaySchedule.self, WorkPlace.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            fatalError("Could not open the Yetsa store")
        }

        Seed.installIfNeeded(container.mainContext)
        ArrivalWatcher.start(in: container.mainContext)
        return container
    }
}

/// Turns a geofence crossing into the one thing it is worth: a note of when
/// you actually got in, and a single quiet notification saying so.
///
/// Lives here rather than in LocationService so the service stays a plain
/// CoreLocation wrapper with no idea what a workday is.
@MainActor
enum ArrivalWatcher {
    static func start(in context: ModelContext) {
        let places = (try? context.fetch(FetchDescriptor<WorkPlace>())) ?? []
        guard let place = places.first, place.isSet else { return }

        LocationService.shared.onArrive = { date in
            record(date, for: place, in: context)
        }
        LocationService.shared.startMonitoring(center: place.coordinate, radius: place.radius)
    }

    private static func record(_ date: Date, for place: WorkPlace, in context: ModelContext) {
        let calendar = Clock.calendar

        // Crossing the line on a Saturday, or popping back at nine at night,
        // is not an arrival worth announcing.
        let weekday = calendar.component(.weekday, from: date)
        let schedules = (try? context.fetch(FetchDescriptor<DaySchedule>())) ?? []
        guard let schedule = schedules.first(where: { $0.weekday == weekday }), schedule.isWorkday else { return }
        guard !place.hasArrived(on: date, calendar: calendar) else { return }

        place.lastArrival = date
        try? context.save()

        announce(date, against: schedule, calendar: calendar)
    }

    private static func announce(_ date: Date, against schedule: DaySchedule, calendar: Calendar) {
        let actual = Clock.minutesFromMidnight(date, calendar: calendar)
        let drift = actual - schedule.arriveWork

        let body: String
        if drift <= -5 {
            body = "\(Clock.durationString(-drift)) earlier than the scaffold says."
        } else if drift >= 5 {
            body = "\(Clock.durationString(drift)) later than the scaffold says."
        } else {
            body = "Right on the scaffold."
        }

        let content = UNMutableNotificationContent()
        content.title = "At work — \(Clock.clockString(date))"
        content.body = body
        content.sound = nil
        content.interruptionLevel = .passive
        content.threadIdentifier = "arrival"

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "arrival-\(actual)", content: content, trigger: nil)
        )
    }
}
