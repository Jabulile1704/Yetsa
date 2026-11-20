import Foundation
import XCTest
@testable import Yetsa

@MainActor
final class SnoozePlanTests: XCTestCase {

    func testChainNeverRunsPastTheBuffer() {
        for buffer in [2, 5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, 120] {
            let plan = SnoozePlan(bufferMinutes: buffer)
            XCTAssertLessThanOrEqual(plan.count * plan.minutes, buffer,
                                     "a \(buffer) min buffer produced \(plan.count) x \(plan.minutes)")
            XCTAssertGreaterThanOrEqual(plan.count, 1)
            XCTAssertGreaterThanOrEqual(plan.minutes, 1)
        }
    }

    func testBufferTooSmallToDivideOffersNoSnooze() {
        for buffer in [0, 1] {
            let plan = SnoozePlan(bufferMinutes: buffer)
            XCTAssertFalse(plan.isAvailable)
            XCTAssertEqual(plan.count, 0)
            XCTAssertEqual(plan.minutes, 0)
        }
    }

    func testFortyFiveMinutesDividesIntoThreeQuarterHours() {
        let plan = SnoozePlan(bufferMinutes: 45)
        XCTAssertEqual(plan.count, 3)
        XCTAssertEqual(plan.minutes, 15)
        XCTAssertEqual(plan.count * plan.minutes, 45)
    }
}

@MainActor
final class ClockTests: XCTestCase {

    func testDurationsReadTheWayAPersonWouldSayThem() {
        XCTAssertEqual(Clock.durationString(0), "0 min")
        XCTAssertEqual(Clock.durationString(35), "35 min")
        XCTAssertEqual(Clock.durationString(60), "1h")
        XCTAssertEqual(Clock.durationString(315), "5h 15")
        XCTAssertEqual(Clock.durationString(-10), "0 min")
    }

    func testShortDurationsFitANarrowColumn() {
        XCTAssertEqual(Clock.shortDuration(5), "5m")
        XCTAssertEqual(Clock.shortDuration(90), "1h30")
        XCTAssertEqual(Clock.shortDuration(120), "2h")
    }

    func testMinutesFromMidnightRoundTrip() {
        let calendar = testCalendar
        let date = Clock.date(on: day(2026, 10, 19), minutes: 405, calendar: calendar)
        XCTAssertEqual(Clock.minutesFromMidnight(date, calendar: calendar), 405)
    }

    func testWeeksAreCountedFromMonday() {
        let calendar = testCalendar
        XCTAssertEqual(Clock.weeksBetween(day(2026, 10, 17), day(2026, 10, 18), calendar: calendar), 0,
                       "Saturday and Sunday share a Monday-first week")
        XCTAssertEqual(Clock.weeksBetween(day(2026, 10, 18), day(2026, 10, 19), calendar: calendar), 1,
                       "Sunday and the Monday after it do not")
    }

    func testNextWeekdayIncludesTheDateItself() {
        let calendar = testCalendar
        let saturday = day(2026, 10, 17)
        XCTAssertEqual(Clock.nextDate(weekday: 7, onOrAfter: saturday, calendar: calendar), saturday)
        XCTAssertEqual(Clock.nextDate(weekday: 7, onOrAfter: day(2026, 10, 18), calendar: calendar), day(2026, 10, 24))
    }
}

@MainActor
final class QuoteTests: XCTestCase {

    func testWholeSetRunsBeforeAnyLineRepeats() {
        let calendar = testCalendar
        let start = day(2026, 10, 19)
        let seen = (0..<Quotes.all.count).map { offset in
            Quotes.forDay(calendar.date(byAdding: .day, value: offset, to: start)!, calendar: calendar)
        }
        XCTAssertEqual(Set(seen).count, Quotes.all.count)
    }

    func testAskingTwiceForTheSameDayGivesTheSameLine() {
        let calendar = testCalendar
        let date = day(2026, 11, 20)
        XCTAssertEqual(Quotes.forDay(date, calendar: calendar), Quotes.forDay(date, calendar: calendar))
    }

    func testDatesFarOutAndBeforeTheEpochStayInRange() {
        let calendar = testCalendar
        XCTAssertTrue(Quotes.all.contains(Quotes.forDay(day(2030, 5, 1), calendar: calendar)))
        XCTAssertTrue(Quotes.all.contains(Quotes.forDay(day(1950, 3, 2), calendar: calendar)))
    }
}
