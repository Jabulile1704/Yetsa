import Foundation
import XCTest
@testable import Yetsa

@MainActor
final class DataExportTests: XCTestCase {

    func testFieldsWithoutPunctuationAreLeftAlone() {
        XCTAssertEqual(DataExport.escape("Iron today's clothes"), "Iron today's clothes")
        XCTAssertEqual(DataExport.escape(""), "")
    }

    func testCommasQuotesAndNewlinesAreQuoted() {
        XCTAssertEqual(DataExport.escape("Cook, then tidy"), "\"Cook, then tidy\"")
        XCTAssertEqual(DataExport.escape("Say \"hello\""), "\"Say \"\"hello\"\"\"")
        XCTAssertEqual(DataExport.escape("line one\nline two"), "\"line one\nline two\"")
    }

    func testCSVHasAHeaderAndOneRowPerTick() {
        let calendar = testCalendar
        let task = TaskItem(title: "Cook, properly", estimateMinutes: 45, context: .home)
        task.project = "Home"

        let done = Completion(forDay: day(2026, 10, 19), actualMinutes: 50)
        let skipped = Completion(forDay: day(2026, 10, 20), wasSkipped: true)
        task.completions = [done, skipped]

        let csv = DataExport.completionsCSV(tasks: [task], calendar: calendar)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 3, "header plus two ticks")
        XCTAssertTrue(lines[0].hasPrefix("Date,Task,Project,Context"))
        XCTAssertTrue(lines[1].contains("\"Cook, properly\""), "a comma in the title must be quoted")
        XCTAssertTrue(lines[1].contains(",50,"), "the measured time should be there")
        XCTAssertTrue(lines[1].hasSuffix(",No"))
        XCTAssertTrue(lines[2].hasSuffix(",Yes"), "a skip is marked as one")
    }

    func testCSVLeavesUnmeasuredTimeBlankRatherThanZero() {
        let task = TaskItem(title: "Shower", estimateMinutes: 15)
        task.completions = [Completion(forDay: day(2026, 10, 19))]

        let csv = DataExport.completionsCSV(tasks: [task], calendar: testCalendar)
        let row = csv.split(separator: "\n")[1]

        XCTAssertTrue(row.contains(",15,,No"), "an unmeasured tick should be blank, not 0: \(row)")
    }

    func testJSONCarriesTheWeekTheTasksAndTheTicks() throws {
        let task = TaskItem(title: "Laundry", estimateMinutes: 90, recurrence: .everyNWeeks)
        task.recurrenceWeekday = 7
        task.recurrenceInterval = 2
        task.recurrenceAnchor = day(2026, 10, 17)
        task.completions = [Completion(forDay: day(2026, 10, 17))]

        let schedules = (1...7).map { workdaySchedule(weekday: $0) }
        let data = try DataExport.json(tasks: [task], schedules: schedules, place: nil)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(parsed["app"] as? String, "Yetsa")
        XCTAssertEqual(parsed["formatVersion"] as? Int, 1)
        XCTAssertEqual((parsed["week"] as? [[String: Any]])?.count, 7)
        XCTAssertNil(parsed["workplace"] as? [String: Any], "an unset place should not be written")

        let tasks = try XCTUnwrap(parsed["tasks"] as? [[String: Any]])
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0]["title"] as? String, "Laundry")
        XCTAssertEqual(tasks[0]["recurrence"] as? String, "everyNWeeks")
        XCTAssertEqual(tasks[0]["recurrenceInterval"] as? Int, 2)
        XCTAssertEqual((tasks[0]["completions"] as? [[String: Any]])?.count, 1)
    }

    func testJSONOmitsFieldsThatDoNotApply() throws {
        let simple = TaskItem(title: "Tidy", estimateMinutes: 10, recurrence: .daily)
        let data = try DataExport.json(tasks: [simple], schedules: [], place: nil)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let task = try XCTUnwrap((parsed["tasks"] as? [[String: Any]])?.first)

        XCTAssertNil(task["quotaPerWeek"], "a daily task has no quota")
        XCTAssertNil(task["batchTotal"], "a task that is not a pile has no total")
        XCTAssertNil(task["preferredWindow"], "no preference means the key is absent")
    }

    func testJSONUsesISODatesSoOtherToolsCanReadIt() throws {
        let task = TaskItem(title: "Anything")
        task.createdAt = day(2026, 10, 19)
        let data = try DataExport.json(tasks: [task], schedules: [], place: nil)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(text.contains("2026-10-1"), "dates should be ISO 8601: \(text.prefix(200))")
    }

    func testTheFilenameIsSortableAndCarriesTheExtension() {
        let name = DataExport.filename(extension: "json", on: day(2026, 10, 19))
        XCTAssertTrue(name.hasPrefix("Yetsa-"))
        XCTAssertTrue(name.hasSuffix(".json"))
        XCTAssertFalse(name.contains("/"), "a slash would make this an invalid filename")
    }
}
