import AppIntents
import Foundation
import SwiftData

/// A task as App Intents sees it: a flat, `Sendable` snapshot, not the live
/// `@Model`. Handing a SwiftData object to the intents runtime would mean
/// handing it across process boundaries it was never meant to cross, so this
/// copies out what Siri needs to show a row and find the thing again.
struct TaskEntity: AppEntity, Identifiable {
    let id: String
    let title: String
    let estimateMinutes: Int
    let cadence: String

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Task", numericFormat: "\(placeholder: .int) tasks")
    }

    nonisolated static let defaultQuery = TaskEntityQuery()

    nonisolated var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(cadence) · \(Clock.durationString(estimateMinutes))"
        )
    }

    @MainActor
    init(_ task: TaskItem) {
        id = TaskToken.string(for: task.persistentModelID) ?? task.title
        title = task.title
        estimateMinutes = task.estimateMinutes
        cadence = RecurrenceEngine.cadence(task, calendar: Clock.calendar)
    }
}

/// Turns a `PersistentIdentifier` into something that survives a round trip
/// through App Intents, which wants a plain `String`.
///
/// Encoding the identifier rather than using the title means ticking by voice
/// cannot settle the wrong task when two share a name. Base64url, because the
/// identifier's JSON contains characters that a URL-shaped identifier space
/// would mangle.
enum TaskToken {
    nonisolated static func string(for id: PersistentIdentifier) -> String? {
        guard let data = try? JSONEncoder().encode(id) else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated static func identifier(from string: String) -> PersistentIdentifier? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Base64 wants a length divisible by four; the padding was dropped to
        // keep the token clean, so put it back before decoding.
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}

/// How Siri finds a task. `EntityStringQuery` is what makes "mark iron my
/// clothes done" work: the system hands over the words it heard and this
/// matches them against titles.
struct TaskEntityQuery: EntityStringQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        let wanted = Set(identifiers)
        return YetsaStore.fetch(TaskItem.self)
            .filter { task in
                guard let token = TaskToken.string(for: task.persistentModelID) else { return false }
                return wanted.contains(token)
            }
            .map(TaskEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [TaskEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        return YetsaStore.fetch(TaskItem.self)
            .filter { !$0.isArchived }
            .filter { $0.title.localizedCaseInsensitiveContains(needle) }
            .sorted { TaskMatch.isBetter($0.title, than: $1.title, for: needle) }
            .map(TaskEntity.init)
    }

    /// What Shortcuts offers before you have typed anything: what is actually
    /// due today, which is a far better guess than the whole pile.
    @MainActor
    func suggestedEntities() async throws -> [TaskEntity] {
        let plan = YetsaStore.plan(for: .now)
        let calendar = Clock.calendar
        return plan.windows
            .flatMap(\.tasks)
            .filter { !RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar) }
            .map(TaskEntity.init)
    }
}

/// Ranking for a spoken match. Pulled out of the query so it can be tested:
/// the intents runtime is not available to the test suite, but this is.
enum TaskMatch {
    /// An exact title beats a prefix, a prefix beats a word boundary, and a
    /// bare substring comes last. Within a tier the shorter title wins, since
    /// "cook" should find "Cook" rather than "Cook for the week ahead".
    nonisolated static func score(_ title: String, for needle: String) -> Int {
        let haystack = title.lowercased()
        let needle = needle.lowercased()
        if haystack == needle { return 0 }
        if haystack.hasPrefix(needle) { return 1 }
        if haystack.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { return 2 }
        if haystack.contains(needle) { return 3 }
        return 4
    }

    nonisolated static func isBetter(_ lhs: String, than rhs: String, for needle: String) -> Bool {
        let left = score(lhs, for: needle)
        let right = score(rhs, for: needle)
        if left != right { return left < right }
        if lhs.count != rhs.count { return lhs.count < rhs.count }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
}
