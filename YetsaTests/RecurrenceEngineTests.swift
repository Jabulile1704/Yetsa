import Foundation
import SwiftData
import XCTest
@testable import Yetsa

@MainActor
final class RecurrenceEngineTests: XCTestCase {

    /// 17 Oct 2026 is a Saturday.
    private let anchorSaturday = day(2026, 10, 17)

    private func fortnightlyLaundry() -> TaskItem {
        let task = TaskItem(title: "Laundry", estimateMinutes: 90, recurrence: .everyNWeeks)
        task.recurrenceWeekday = 7
        task.recurrenceInterval = 2
        task.recurrenceAnchor = anchorSaturday
        return task
    }

    func testFortnightlyFallsOnTheAnchorWeekAndSkipsTheOneBetween() throws {
        let task = fortnightlyLaundry()
        let calendar = testCalendar

        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 17), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isDue(task, on: day(2026, 10, 24), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 31), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isDue(task, on: day(2026, 11, 7), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 11, 14), calendar: calendar))
    }

    func testFortnightlyNeverLandsOnAnotherWeekday() throws {
        let task = fortnightlyLaundry()
        let calendar = testCalendar

        for offset in 0..<28 {
            let date = calendar.date(byAdding: .day, value: offset, to: anchorSaturday)!
            if RecurrenceEngine.isDue(task, on: date, calendar: calendar) {
                XCTAssertEqual(calendar.component(.weekday, from: date), 7,
                               "fired on a \(date), which is not a Saturday")
            }
        }
    }

    func testSkippingOneDoesNotShiftTheRhythm() throws {
        let task = fortnightlyLaundry()
        let calendar = testCalendar

        RecurrenceEngine.skip(task, on: anchorSaturday, calendar: calendar)

        XCTAssertTrue(RecurrenceEngine.isSkipped(task, on: anchorSaturday, calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isTicked(task, on: anchorSaturday, calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isDue(task, on: day(2026, 10, 24), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 31), calendar: calendar))
    }

    func testQuotaCountsRealCompletionsAndIgnoresSkips() throws {
        let calendar = testCalendar
        let cook = TaskItem(title: "Cook", estimateMinutes: 45, recurrence: .weeklyQuota)
        cook.quotaPerWeek = 2

        let monday = day(2026, 10, 19)

        XCTAssertEqual(RecurrenceEngine.quotaDone(cook, inWeekOf: monday, calendar: calendar), 0)

        RecurrenceEngine.toggle(cook, on: monday, calendar: calendar)
        XCTAssertEqual(RecurrenceEngine.quotaDone(cook, inWeekOf: monday, calendar: calendar), 1)

        RecurrenceEngine.skip(cook, on: day(2026, 10, 20), calendar: calendar)
        XCTAssertEqual(RecurrenceEngine.quotaDone(cook, inWeekOf: monday, calendar: calendar), 1,
                       "a skip must not count towards a quota")

        RecurrenceEngine.toggle(cook, on: day(2026, 10, 21), calendar: calendar)
        XCTAssertEqual(RecurrenceEngine.quotaDone(cook, inWeekOf: monday, calendar: calendar), 2)
        XCTAssertEqual(RecurrenceEngine.quotaRemaining(cook, inWeekOf: monday, calendar: calendar), 0)
    }

    func testQuotaResetsWithTheWeek() throws {
        let calendar = testCalendar
        let cook = TaskItem(title: "Cook", recurrence: .weeklyQuota)
        cook.quotaPerWeek = 2

        RecurrenceEngine.toggle(cook, on: day(2026, 10, 19), calendar: calendar)
        XCTAssertEqual(RecurrenceEngine.quotaDone(cook, inWeekOf: day(2026, 10, 19), calendar: calendar), 1)
        XCTAssertEqual(RecurrenceEngine.quotaDone(cook, inWeekOf: day(2026, 10, 26), calendar: calendar), 0)
    }

    func testOneOffSettlesOnceAndDoesNotComeBack() throws {
        let calendar = testCalendar
        let task = TaskItem(title: "Renew licence", recurrence: .once, dueDate: day(2026, 10, 19))

        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 19), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 21), calendar: calendar),
                      "an open one-off should keep showing rather than falling off the back")

        RecurrenceEngine.toggle(task, on: day(2026, 10, 21), calendar: calendar)

        XCTAssertTrue(RecurrenceEngine.isTicked(task, on: day(2026, 10, 21), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isTicked(task, on: day(2026, 10, 22), calendar: calendar),
                      "settled on Wednesday should still read as done on Thursday")
        XCTAssertFalse(RecurrenceEngine.isDue(task, on: day(2026, 10, 22), calendar: calendar))
    }

    func testAfterCompletionCountsFromTheTickNotTheCalendar() throws {
        let calendar = testCalendar
        let task = TaskItem(title: "Haircut", recurrence: .afterCompletion)
        task.recurrenceInterval = 42

        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 19), calendar: calendar))

        RecurrenceEngine.toggle(task, on: day(2026, 10, 19), calendar: calendar)

        XCTAssertFalse(RecurrenceEngine.isDue(task, on: day(2026, 11, 20), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 11, 30), calendar: calendar))
    }

    func testWeekdaysMeansMondayToFriday() throws {
        let calendar = testCalendar
        let task = TaskItem(title: "Iron", recurrence: .weekdays)

        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 19), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isDue(task, on: day(2026, 10, 23), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isDue(task, on: day(2026, 10, 24), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isDue(task, on: day(2026, 10, 25), calendar: calendar))
    }

    func testUntogglingRemovesTheCompletion() throws {
        let calendar = testCalendar
        let task = TaskItem(title: "Tidy", recurrence: .daily)

        RecurrenceEngine.toggle(task, on: day(2026, 10, 19), calendar: calendar)
        XCTAssertEqual(task.realCompletions.count, 1)

        RecurrenceEngine.toggle(task, on: day(2026, 10, 19), calendar: calendar)
        XCTAssertTrue(task.realCompletions.isEmpty)
        XCTAssertNil(task.lastCompletedAt)
    }

    func testMeasuredAverageNeedsEnoughEvidence() throws {
        let task = TaskItem(title: "Shower", estimateMinutes: 15)

        for minutes in [18, 20] {
            let completion = Completion(forDay: .now, actualMinutes: minutes)
            completion.task = task
            task.completions.append(completion)
        }
        XCTAssertNil(RecurrenceEngine.measuredAverage(task), "two samples is not enough to argue with an estimate")

        let third = Completion(forDay: .now, actualMinutes: 22)
        third.task = task
        task.completions.append(third)
        XCTAssertEqual(RecurrenceEngine.measuredAverage(task), 20)
    }
}
