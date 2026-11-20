import Foundation
import SwiftData
import XCTest
@testable import Yetsa

@MainActor
final class DayPlannerTests: XCTestCase {

    private let monday = day(2026, 10, 19)
    private let friday = day(2026, 10, 23)
    private let saturday = day(2026, 10, 24)

    func testWorkdayBuildsTheFullScaffoldInOrder() throws {
        let plan = DayPlanner.plan(for: monday, schedule: workdaySchedule(weekday: 2), tasks: [], calendar: testCalendar)

        XCTAssertEqual(plan.windows.map(\.kind),
                       [.morning, .commuteOut, .workMorning, .lunch, .workAfternoon, .commuteHome, .evening])
        XCTAssertTrue(plan.isWorkday)
        XCTAssertNotNil(plan.departure)
    }

    func testDayOffDropsWorkAndTheCommute() throws {
        let plan = DayPlanner.plan(for: saturday, schedule: DaySchedule(weekday: 7, isWorkday: false), tasks: [], calendar: testCalendar)

        XCTAssertEqual(plan.windows.map(\.kind), [.morning, .afternoon, .evening])
        XCTAssertFalse(plan.isWorkday)
        XCTAssertNil(plan.departure)
    }

    func testMorningWindowIsTheGapBetweenGettingUpAndTheDoor() throws {
        let plan = DayPlanner.plan(for: monday, schedule: workdaySchedule(weekday: 2), tasks: [], calendar: testCalendar)
        XCTAssertEqual(plan.window(.morning)?.capacityMinutes, 60)
    }

    func testPlannedRemainingAndFreeAddUp() throws {
        let calendar = testCalendar

        let iron = TaskItem(title: "Iron", estimateMinutes: 10, preferredWindow: .morning, recurrence: .weekdays)
        let shower = TaskItem(title: "Shower", estimateMinutes: 15, preferredWindow: .morning, recurrence: .weekdays)
        let pack = TaskItem(title: "Pack", estimateMinutes: 5, preferredWindow: .morning, recurrence: .weekdays)
        let tasks = [iron, shower, pack]

        var morning = try XCTUnwrap(
            DayPlanner.plan(for: monday, schedule: workdaySchedule(weekday: 2), tasks: tasks, calendar: calendar).window(.morning)
        )
        XCTAssertEqual(morning.plannedMinutes, 30)
        XCTAssertEqual(morning.remainingMinutes, 30)
        XCTAssertEqual(morning.freeMinutes, 30)
        XCTAssertFalse(morning.isOverbooked)

        // Ticking one leaves the plan alone but shrinks what is left to do.
        RecurrenceEngine.toggle(iron, on: monday, calendar: calendar)
        morning = try XCTUnwrap(
            DayPlanner.plan(for: monday, schedule: workdaySchedule(weekday: 2), tasks: tasks, calendar: calendar).window(.morning)
        )
        XCTAssertEqual(morning.plannedMinutes, 30)
        XCTAssertEqual(morning.remainingMinutes, 20)
    }

    func testOverbookingIsReportedNotClampedAway() throws {
        let hog = TaskItem(title: "Too much", estimateMinutes: 90, preferredWindow: .morning, recurrence: .daily)

        let morning = try XCTUnwrap(
            DayPlanner.plan(for: monday, schedule: workdaySchedule(weekday: 2), tasks: [hog], calendar: testCalendar).window(.morning)
        )
        XCTAssertTrue(morning.isOverbooked)
        XCTAssertEqual(morning.freeMinutes, -30)
        XCTAssertGreaterThan(morning.loadFraction, 1)
    }

    func testTaskLandsInAWindowThatAcceptsItsContext() throws {
        let deskJob = TaskItem(title: "Review", estimateMinutes: 30, context: .work, recurrence: .weekdays)

        let plan = DayPlanner.plan(for: monday, schedule: workdaySchedule(weekday: 2), tasks: [deskJob], calendar: testCalendar)

        XCTAssertTrue(plan.window(.workMorning)?.tasks.contains { $0.title == "Review" } ?? false)
        XCTAssertTrue(plan.window(.morning)?.tasks.isEmpty ?? false)
    }

    func testFridaysEarlierKnockOffLengthensTheEvening() throws {
        let thursday = DayPlanner.plan(for: day(2026, 10, 22), schedule: workdaySchedule(weekday: 5), tasks: [], calendar: testCalendar)
        let fridayPlan = DayPlanner.plan(for: friday, schedule: workdaySchedule(weekday: 6), tasks: [], calendar: testCalendar)

        let thursdayEvening = try XCTUnwrap(thursday.window(.evening)).capacityMinutes
        let fridayEvening = try XCTUnwrap(fridayPlan.window(.evening)).capacityMinutes
        XCTAssertEqual(fridayEvening, thursdayEvening + 30)

        let thursdayAfternoon = try XCTUnwrap(thursday.window(.workAfternoon)).capacityMinutes
        let fridayAfternoon = try XCTUnwrap(fridayPlan.window(.workAfternoon)).capacityMinutes
        XCTAssertEqual(fridayAfternoon, thursdayAfternoon - 30)
    }

    func testEveryWindowIsFollowedByTheAnchorItRunsInto() throws {
        let plan = DayPlanner.plan(for: monday, schedule: workdaySchedule(weekday: 2), tasks: [], calendar: testCalendar)

        XCTAssertEqual(plan.anchorAfter(.morning)?.id, "leave")
        XCTAssertEqual(plan.anchorAfter(.workMorning)?.id, "lunch")
        XCTAssertEqual(plan.anchorAfter(.evening)?.id, "bed")
    }
}
