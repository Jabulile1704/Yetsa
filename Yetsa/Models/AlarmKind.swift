import Foundation

/// The three moments that need more than a notification. A notification is
/// silenced by a Focus and ignored by a sleeping person; an alarm breaks
/// through both, so these are the points where being late actually costs
/// something.
enum AlarmKind: String, CaseIterable, Identifiable, Sendable {
    case wake
    case leaveHome
    case knockOff

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wake: "Wake up"
        case .leaveHome: "Leave home"
        case .knockOff: "Knock off"
        }
    }

    var blurb: String {
        switch self {
        case .wake: "At your alarm time. The only one that can be snoozed."
        case .leaveHome: "The moment you have to be out of the door."
        case .knockOff: "Ends the working day, including Friday's earlier one."
        }
    }

    var symbol: String {
        switch self {
        case .wake: "alarm"
        case .leaveHome: "figure.walk.departure"
        case .knockOff: "door.left.hand.open"
        }
    }

    /// Snoozing a wake-up is the whole point of a wake-up. Snoozing the door
    /// just makes you late, so the other two offer no way out but Stop.
    var allowsSnooze: Bool { self == .wake }

    var snoozeMinutes: Int { 15 }

    var defaultsKey: String { "alarm.\(rawValue)" }

    /// Off until asked for — an app that starts making noise at 05:45 without
    /// being told to is not a good houseguest.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Where this alarm sits in a day's scaffold.
    func minutes(in schedule: DaySchedule) -> Int {
        switch self {
        case .wake: schedule.wake
        case .leaveHome: schedule.leaveHome
        case .knockOff: schedule.knockOff
        }
    }

    /// All three are anchored to work, so a day off stays quiet. Marking a
    /// weekend as a working day in Setup brings them with it.
    func applies(to schedule: DaySchedule) -> Bool {
        schedule.isWorkday
    }

    /// The anchor on the Today timeline this alarm guards, so the row can show
    /// a bell.
    var anchorID: String {
        switch self {
        case .wake: "wake"
        case .leaveHome: "leave"
        case .knockOff: "knockOff"
        }
    }
}
