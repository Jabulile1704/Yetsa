import Foundation

/// Where a task can actually be done. Today only offers you the contexts that
/// fit the window you are standing in — there is no point showing `@errand`
/// while you are at your desk at 10am.
enum TaskContext: String, CaseIterable, Identifiable, Sendable {
    case home
    case work
    case lunch
    case errand
    case phone
    case anywhere

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: "At home"
        case .work: "At work"
        case .lunch: "Lunch break"
        case .errand: "Out / errand"
        case .phone: "Phone or laptop"
        case .anywhere: "Anywhere"
        }
    }

    var tag: String {
        switch self {
        case .home: "@home"
        case .work: "@work"
        case .lunch: "@lunch"
        case .errand: "@errand"
        case .phone: "@phone"
        case .anywhere: "@anywhere"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .work: "building.2"
        case .lunch: "fork.knife"
        case .errand: "bag"
        case .phone: "iphone"
        case .anywhere: "globe"
        }
    }

    nonisolated static func stored(_ raw: String) -> TaskContext {
        TaskContext(rawValue: raw) ?? .anywhere
    }
}
