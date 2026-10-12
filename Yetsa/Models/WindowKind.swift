import Foundation

/// The slices a day breaks into. Work blocks and commutes are part of the
/// scaffold too — they are shown so the day reads as one continuous thing,
/// but only the non-work windows are budgeted against your own time.
enum WindowKind: String, CaseIterable, Identifiable, Sendable {
    case morning
    case commuteOut
    case workMorning
    case lunch
    case workAfternoon
    case commuteHome
    case evening
    case afternoon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: "Morning at home"
        case .commuteOut: "Commute in"
        case .workMorning: "Work — morning"
        case .lunch: "Lunch break"
        case .workAfternoon: "Work — afternoon"
        case .commuteHome: "Commute home"
        case .evening: "Evening"
        case .afternoon: "Afternoon"
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sunrise"
        case .commuteOut: "car"
        case .workMorning: "building.2"
        case .lunch: "fork.knife"
        case .workAfternoon: "building.2"
        case .commuteHome: "car.rear"
        case .evening: "moon.stars"
        case .afternoon: "sun.max"
        }
    }

    /// Work blocks belong to your employer, not to your task budget.
    var isWork: Bool {
        self == .workMorning || self == .workAfternoon
    }

    /// Fifteen minutes behind the wheel is not fifteen minutes of desk time,
    /// so a commute only accepts things you can do while moving.
    var isCommute: Bool {
        self == .commuteOut || self == .commuteHome
    }

    var contexts: Set<TaskContext> {
        switch self {
        case .morning, .evening: [.home, .phone, .anywhere]
        case .afternoon: [.home, .phone, .errand, .anywhere]
        case .commuteOut: [.phone, .anywhere]
        case .commuteHome: [.phone, .errand, .anywhere]
        case .workMorning, .workAfternoon: [.work]
        case .lunch: [.lunch, .phone, .errand, .anywhere]
        }
    }

    func accepts(_ context: TaskContext) -> Bool {
        contexts.contains(context)
    }

    nonisolated static func stored(_ raw: String) -> WindowKind? {
        WindowKind(rawValue: raw)
    }
}
