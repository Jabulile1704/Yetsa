import Foundation
import SwiftData
@testable import Yetsa

/// A fixed calendar so a test never depends on the machine's locale.
var testCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    calendar.timeZone = TimeZone(identifier: "Africa/Johannesburg") ?? .gmt
    return calendar
}

func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    testCalendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
}

/// The weekday scaffold the app seeds: up at 06:30, out at 07:30, desk at
/// 07:45, lunch at 13:00, knock off at 16:30 — 16:00 on a Friday.
@MainActor
func workdaySchedule(weekday: Int) -> DaySchedule {
    let schedule = DaySchedule(weekday: weekday, isWorkday: true)
    schedule.wake = 5 * 60 + 45
    schedule.outOfBed = 6 * 60 + 30
    schedule.leaveHome = 7 * 60 + 30
    schedule.arriveWork = 7 * 60 + 45
    schedule.lunch = 13 * 60
    schedule.lunchLength = 45
    schedule.knockOff = weekday == 6 ? 16 * 60 : 16 * 60 + 30
    schedule.eveningStarts = 17 * 60
    schedule.bedtime = 22 * 60 + 15
    return schedule
}
