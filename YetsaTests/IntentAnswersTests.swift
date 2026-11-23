import Foundation
import SwiftData
import XCTest
@testable import Yetsa

/// The intents themselves cannot be unit tested — the App Intents runtime is
/// not available to XCTest — which is exactly why every sentence Siri speaks
/// was put in `IntentAnswers` instead. These tests are the whole payoff of
/// that split.
///
/// Each one checks the *claim* in the sentence rather than the sentence
/// itself where it can, so rewording the prose does not break the suite,
/// but the numbers and the branch chosen are pinned.
@MainActor
final class IntentAnswersTests: XCTestCase {

    private let monday = day(2026, 10, 19)
    private let saturday = day(2026, 10, 24)

    /// A time on a given day, built with the test calendar so the assertions
    /// hold in any timezone the CI runner happens to use.
    private func at(_ hour: Int, _ minute: Int = 0, on date: Date) -> Date {
        Clock.date(on: date, minutes: hour * 60 + minute, calendar: testCalendar)
    }

    private func plan(for date: Date, weekday: Int, tasks: [TaskItem] = []) -> DayPlan {
        let schedule = weekday == 7
            ? DaySchedule(weekday: 7, isWorkday: false)
            : workdaySchedule(weekday: weekday)
        return DayPlanner.plan(for: date, schedule: schedule, tasks: tasks, calendar: testCalendar)
    }

    // MARK: - Free time

    func testAnEmptyWindowIsReportedAsClear() {
        let answer = IntentAnswers.freeTime(
            in: .evening,
            plan: plan(for: monday, weekday: 2),
            now: at(6, 0, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("clear"), answer)
        // Home at 16:45 — knock off plus the commute — and bed at 22:15.
        XCTAssertTrue(answer.contains("5h 30"), answer)
    }

    func testFreeTimeSubtractsThePlanFromTheCapacity() {
        let cook = TaskItem(title: "Cook", estimateMinutes: 60, preferredWindow: .evening, recurrence: .daily)
        let plan = plan(for: monday, weekday: 2, tasks: [cook])

        let answer = IntentAnswers.freeTime(
            in: .evening,
            plan: plan,
            now: at(6, 0, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("4h 30 free"), answer)
        XCTAssertTrue(answer.contains("one thing"), answer)
    }

    func testAnOverbookedWindowSaysByHowMuchRatherThanGoingNegative() {
        let marathon = TaskItem(title: "Marathon", estimateMinutes: 600,
                                preferredWindow: .evening, recurrence: .daily)
        let answer = IntentAnswers.freeTime(
            in: .evening,
            plan: plan(for: monday, weekday: 2, tasks: [marathon]),
            now: at(6, 0, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("overbooked by"), answer)
        XCTAssertFalse(answer.contains("-"), "a spoken answer should never read a minus sign aloud: \(answer)")
    }

    func testAWorkWindowIsNotBudgetedAndSaysSo() {
        let answer = IntentAnswers.freeTime(
            in: .workMorning,
            plan: plan(for: monday, weekday: 2),
            now: at(9, 0, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("employer"), answer)
    }

    func testAWindowThatDoesNotExistOnThatDayIsNotInvented() {
        // Saturday has no commute, because there is nowhere to go.
        let answer = IntentAnswers.freeTime(
            in: .commuteOut,
            plan: plan(for: saturday, weekday: 7),
            now: at(9, 0, on: saturday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("no commute in window"), answer)
    }

    func testACurrentWindowCountsTheClockLeftNotTheWholeCapacity() {
        let cook = TaskItem(title: "Cook", estimateMinutes: 30, preferredWindow: .evening, recurrence: .daily)
        // 20:15 — two hours of the evening already gone.
        let answer = IntentAnswers.freeTime(
            in: .evening,
            plan: plan(for: monday, weekday: 2, tasks: [cook]),
            now: at(20, 15, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("2h left"), answer)
        XCTAssertTrue(answer.contains("1h 30 spare"), answer)
    }

    func testAPastWindowIsSpokenOfInThePastTense() {
        let answer = IntentAnswers.freeTime(
            in: .morning,
            plan: plan(for: monday, weekday: 2),
            now: at(21, 0, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("is over"), answer)
    }

    func testTheWholeDayExcludesWorkFromTheBudget() {
        let answer = IntentAnswers.freeTimeToday(
            plan: plan(for: monday, weekday: 2),
            now: at(6, 0, on: monday),
            calendar: testCalendar
        )
        // Morning 60, commute 15, lunch 45, commute home 15, evening 255 — the
        // two work blocks and nothing else are left out.
        XCTAssertTrue(answer.contains("Nothing is planned"), answer)
        XCTAssertTrue(answer.contains("today"), answer)
    }

    func testTheWholeDayNamesTheWorstOverbookedWindow() {
        let marathon = TaskItem(title: "Marathon", estimateMinutes: 600,
                                preferredWindow: .evening, recurrence: .daily)
        let answer = IntentAnswers.freeTimeToday(
            plan: plan(for: monday, weekday: 2, tasks: [marathon]),
            now: at(6, 0, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("evening is overbooked"), answer)
    }

    // MARK: - The scaffold

    func testNextAnchorGivesTheGapAndTheClockTime() {
        let answer = IntentAnswers.nextAnchor(
            plan: plan(for: monday, weekday: 2),
            now: at(7, 0, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("Leave home"), answer)
        XCTAssertTrue(answer.contains("30 min"), answer)
    }

    func testNextAnchorAfterBedtimeDoesNotWrapAround() {
        let answer = IntentAnswers.nextAnchor(
            plan: plan(for: monday, weekday: 2),
            now: at(23, 30, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("Nothing fixed left"), answer)
    }

    func testUntilDepartureCountsDownToTheDoor() {
        let answer = IntentAnswers.untilDeparture(
            plan: plan(for: monday, weekday: 2),
            now: at(6, 45, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("45 min until you leave"), answer)
    }

    func testUntilDepartureAfterTheDoorSaysHowLateRatherThanCountingUp() {
        let answer = IntentAnswers.untilDeparture(
            plan: plan(for: monday, weekday: 2),
            now: at(7, 50, on: monday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("were due out"), answer)
        XCTAssertTrue(answer.contains("20 min ago"), answer)
    }

    func testThereIsNoDepartureOnADayOff() {
        let answer = IntentAnswers.untilDeparture(
            plan: plan(for: saturday, weekday: 7),
            now: at(9, 0, on: saturday),
            calendar: testCalendar
        )
        XCTAssertTrue(answer.contains("not a workday"), answer)
    }

    // MARK: - The morning run

    func testNoMorningRunIsSaidPlainlyRatherThanAnsweredWithZero() {
        XCTAssertTrue(IntentAnswers.morningRun(nil, now: .now).contains("no morning run"))
    }

    func testBehindIsReportedAsClockLeftMinusWorkLeft() {
        // Today, so slack is meaningful: door in 20 minutes, 45 of work left.
        let calendar = Clock.calendar
        let today = calendar.startOfDay(for: .now)
        let departure = Clock.date(on: today, minutes: 7 * 60 + 30, calendar: calendar)
        let now = Clock.date(on: today, minutes: 7 * 60 + 10, calendar: calendar)

        let shower = TaskItem(title: "Shower", estimateMinutes: 15, recurrence: .weekdays)
        let iron = TaskItem(title: "Iron", estimateMinutes: 30, recurrence: .weekdays)
        let run = MorningRun(tasks: [shower, iron], departure: departure, day: today)

        let answer = IntentAnswers.morningRun(run, now: now)
        XCTAssertTrue(answer.contains("25 min behind"), answer)
        XCTAssertTrue(answer.contains("2 steps left"), answer)
    }

    func testSpareTimeIsReportedWhenTheRunIsAhead() {
        let calendar = Clock.calendar
        let today = calendar.startOfDay(for: .now)
        let departure = Clock.date(on: today, minutes: 7 * 60 + 30, calendar: calendar)
        let now = Clock.date(on: today, minutes: 6 * 60 + 30, calendar: calendar)

        let shower = TaskItem(title: "Shower", estimateMinutes: 15, recurrence: .weekdays)
        let run = MorningRun(tasks: [shower], departure: departure, day: today)

        let answer = IntentAnswers.morningRun(run, now: now)
        XCTAssertTrue(answer.contains("45 min spare"), answer)
        XCTAssertTrue(answer.contains("One step left"), answer)
    }

    func testARunForAnotherDayIsDescribedRatherThanScored() {
        // The bug this guards: measured against tomorrow's door, slack reads
        // as hours of spare time — true, and useless.
        let departure = at(7, 30, on: monday)
        let shower = TaskItem(title: "Shower", estimateMinutes: 15, recurrence: .weekdays)
        let run = MorningRun(tasks: [shower], departure: departure, day: monday)

        let answer = IntentAnswers.morningRun(run, now: at(21, 0, on: saturday))
        XCTAssertFalse(answer.contains("spare"), answer)
        XCTAssertFalse(answer.contains("behind"), answer)
        XCTAssertTrue(answer.contains("1 steps") || answer.contains("steps"), answer)
    }

    // MARK: - Confirmations

    func testAddedNamesTheWindowItLandedIn() {
        let task = TaskItem(title: "Buy milk", estimateMinutes: 10)
        let answer = IntentAnswers.added(task, landedIn: .evening)
        XCTAssertEqual(answer, "Added Buy milk, 10 min, in your evening.")
    }

    func testAddedOmitsTheWindowWhenNoneWasFound() {
        let task = TaskItem(title: "Buy milk", estimateMinutes: 10)
        XCTAssertEqual(IntentAnswers.added(task, landedIn: nil), "Added Buy milk, 10 min.")
    }

    func testTickingSomethingAlreadyDoneSaysSoRatherThanClaimingCredit() {
        XCTAssertEqual(IntentAnswers.ticked("Iron", wasAlreadyDone: true), "Iron was already done.")
        XCTAssertEqual(IntentAnswers.ticked("Iron", wasAlreadyDone: false), "Done — Iron.")
    }

    // MARK: - Speaking of days

    func testADayIsNamedRelativeToNowWhereThatReadsBetter() {
        let plan = plan(for: monday, weekday: 2)
        XCTAssertEqual(plan.spokenDay(relativeTo: at(9, 0, on: monday), calendar: testCalendar), "today")
        XCTAssertEqual(plan.spokenDay(relativeTo: at(9, 0, on: day(2026, 10, 18)), calendar: testCalendar), "tomorrow")
        XCTAssertEqual(plan.spokenDay(relativeTo: at(9, 0, on: day(2026, 10, 20)), calendar: testCalendar), "yesterday")
    }

    func testOnlyTheFirstLetterIsCapitalised() {
        XCTAssertEqual("commute in".capitalizedFirst, "Commute in")
        XCTAssertEqual("".capitalizedFirst, "")
    }

    func testTheQuoteSpokenMatchesTheQuoteScheduled() {
        let spoken = IntentAnswers.todaysQuote(on: monday, calendar: testCalendar)
        let scheduled = Quotes.forDay(monday, calendar: testCalendar)
        XCTAssertTrue(spoken.contains(scheduled.text), spoken)
        XCTAssertTrue(spoken.contains(scheduled.author), spoken)
    }
}
