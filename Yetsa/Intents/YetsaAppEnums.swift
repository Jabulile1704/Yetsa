import AppIntents

/// The app's own enums, taught to App Intents rather than duplicated for it.
///
/// `WindowKind` and `TaskContext` are already `String`-backed, `CaseIterable`,
/// `Identifiable` and `Sendable`, which is exactly what `AppEnum` asks for, so
/// conforming them in place beats a parallel set of intent-only enums that
/// would need keeping in step.

extension WindowKind: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Window", numericFormat: "\(placeholder: .int) windows")
    }

    /// Spoken-first, because this is what Siri offers in a disambiguation
    /// list and reads back. Work blocks and commutes are listed: asking what
    /// is free at work is a fair question, and the answer that it is not your
    /// time to spend is a useful thing to hear.
    nonisolated static var caseDisplayRepresentations: [WindowKind: DisplayRepresentation] {
        [
            .morning: DisplayRepresentation(title: "Morning at home", image: .init(systemName: "sunrise")),
            .commuteOut: DisplayRepresentation(title: "Commute in", image: .init(systemName: "car")),
            .workMorning: DisplayRepresentation(title: "Morning at work", image: .init(systemName: "building.2")),
            .lunch: DisplayRepresentation(title: "Lunch break", image: .init(systemName: "fork.knife")),
            .workAfternoon: DisplayRepresentation(title: "Afternoon at work", image: .init(systemName: "building.2")),
            .commuteHome: DisplayRepresentation(title: "Commute home", image: .init(systemName: "car.rear")),
            .evening: DisplayRepresentation(title: "Evening", image: .init(systemName: "moon.stars")),
            .afternoon: DisplayRepresentation(title: "Afternoon", image: .init(systemName: "sun.max"))
        ]
    }
}

extension TaskContext: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Context", numericFormat: "\(placeholder: .int) contexts")
    }

    nonisolated static var caseDisplayRepresentations: [TaskContext: DisplayRepresentation] {
        [
            .home: DisplayRepresentation(title: "At home", image: .init(systemName: "house")),
            .work: DisplayRepresentation(title: "At work", image: .init(systemName: "building.2")),
            .lunch: DisplayRepresentation(title: "Lunch break", image: .init(systemName: "fork.knife")),
            .errand: DisplayRepresentation(title: "Out or errand", image: .init(systemName: "bag")),
            .phone: DisplayRepresentation(title: "Phone or laptop", image: .init(systemName: "iphone")),
            .anywhere: DisplayRepresentation(title: "Anywhere", image: .init(systemName: "globe"))
        ]
    }
}
