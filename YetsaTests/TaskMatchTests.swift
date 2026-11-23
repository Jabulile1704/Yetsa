import Foundation
import SwiftData
import XCTest
@testable import Yetsa

/// How a spoken phrase finds a task, and how a task survives the round trip
/// through App Intents as a plain string.
final class TaskMatchTests: XCTestCase {

    func testAnExactTitleBeatsEverythingElse() {
        XCTAssertEqual(TaskMatch.score("Cook", for: "cook"), 0)
        XCTAssertLessThan(TaskMatch.score("Cook", for: "cook"), TaskMatch.score("Cook for the week", for: "cook"))
    }

    func testAPrefixBeatsAWordInTheMiddle() {
        XCTAssertLessThan(
            TaskMatch.score("Iron my clothes", for: "iron"),
            TaskMatch.score("Buy an iron", for: "iron")
        )
    }

    func testAWordBoundaryBeatsABareSubstring() {
        // "ironing" contains "iron" at a word start; "environment" buries it.
        XCTAssertLessThan(
            TaskMatch.score("Do the ironing", for: "iron"),
            TaskMatch.score("Tidy the environment", for: "iron")
        )
    }

    func testNoMatchScoresWorstOfAll() {
        XCTAssertEqual(TaskMatch.score("Laundry", for: "cook"), 4)
    }

    func testTheShorterTitleWinsWithinATier() {
        XCTAssertTrue(TaskMatch.isBetter("Cook", than: "Cook something nice", for: "cook"))
    }

    func testRankingIsDeterministicForIdenticalScores() {
        // Same tier, same length — falls back to alphabetical rather than to
        // whatever order the store happened to return.
        XCTAssertTrue(TaskMatch.isBetter("Bake", than: "Cook", for: "ake"))
        XCTAssertFalse(TaskMatch.isBetter("Cook", than: "Bake", for: "ake"))
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(TaskMatch.score("IRON MY CLOTHES", for: "iron"), 1)
        XCTAssertEqual(TaskMatch.score("iron my clothes", for: "IRON"), 1)
    }

    // MARK: - Tokens

    func testATokenSurvivesTheRoundTrip() throws {
        let container = try ModelContainer(
            for: Schema([TaskItem.self, Completion.self, DaySchedule.self, WorkPlace.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let task = TaskItem(title: "Iron my clothes")
        context.insert(task)

        let token = try XCTUnwrap(TaskToken.string(for: task.persistentModelID))
        XCTAssertEqual(TaskToken.identifier(from: token), task.persistentModelID)
    }

    func testATokenIsUrlSafe() throws {
        let container = try ModelContainer(
            for: Schema([TaskItem.self, Completion.self, DaySchedule.self, WorkPlace.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let task = TaskItem(title: "Iron my clothes")
        context.insert(task)

        let token = try XCTUnwrap(TaskToken.string(for: task.persistentModelID))
        XCTAssertFalse(token.contains("+"))
        XCTAssertFalse(token.contains("/"))
        XCTAssertFalse(token.contains("="))
    }

    func testRubbishDecodesToNothingRatherThanCrashing() {
        XCTAssertNil(TaskToken.identifier(from: "not a token"))
        XCTAssertNil(TaskToken.identifier(from: ""))
        XCTAssertNil(TaskToken.identifier(from: "YWJjZA"))
    }
}
