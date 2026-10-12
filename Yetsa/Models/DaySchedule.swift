import Foundation
import SwiftData

/// One weekday's fixed scaffold. Times are stored as minutes from midnight so
/// they survive timezone changes and compare cheaply — 345 is 05:45.
@Model
final class DaySchedule {
    /// `Calendar` numbering: 1 = Sunday … 7 = Saturday.
    @Attribute(.unique) var weekday: Int = 2
    var isWorkday: Bool = true

    var wake: Int = 5 * 60 + 45
    var outOfBed: Int = 6 * 60 + 30
    var leaveHome: Int = 7 * 60 + 30
    var arriveWork: Int = 7 * 60 + 45
    var lunch: Int = 13 * 60
    var lunchLength: Int = 45
    var knockOff: Int = 16 * 60 + 30
    var eveningStarts: Int = 17 * 60
    var bedtime: Int = 22 * 60 + 15

    init(weekday: Int, isWorkday: Bool = true) {
        self.weekday = weekday
        self.isWorkday = isWorkday
    }

    var name: String { Weekday.name(weekday) }
    var shortName: String { Weekday.shortName(weekday) }

    /// Getting home takes as long as getting to work did.
    var commuteMinutes: Int { max(0, arriveWork - leaveHome) }
    var homeAgain: Int { knockOff + commuteMinutes }

    /// The window between getting out of bed and walking out the door. The
    /// number that decides whether a morning works.
    var morningCapacity: Int { max(0, leaveHome - outOfBed) }

    /// How long the alarm buys you before you genuinely have to move.
    var snoozeBuffer: Int { max(0, outOfBed - wake) }
}

enum Weekday {
    static let orderedMondayFirst = [2, 3, 4, 5, 6, 7, 1]

    nonisolated static func name(_ weekday: Int) -> String {
        switch weekday {
        case 1: "Sunday"
        case 2: "Monday"
        case 3: "Tuesday"
        case 4: "Wednesday"
        case 5: "Thursday"
        case 6: "Friday"
        case 7: "Saturday"
        default: "—"
        }
    }

    nonisolated static func shortName(_ weekday: Int) -> String {
        String(name(weekday).prefix(3))
    }
}
