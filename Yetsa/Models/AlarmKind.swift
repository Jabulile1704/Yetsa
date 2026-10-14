import Foundation

/// How the gap between the alarm and the moment you genuinely have to move
/// divides into snoozes. Snoozing is only honest if it runs out: an alarm you
/// can push back forever is not an alarm.
struct SnoozePlan {
    let bufferMinutes: Int

    /// What a snooze would ideally be, before the buffer gets a say.
    private static let preferred = 15

    var isAvailable: Bool { bufferMinutes >= 2 }

    /// How many snoozes fit, rounding to whichever count lands closest to the
    /// preferred length.
    var count: Int {
        guard isAvailable else { return 0 }
        return max(1, Int((Double(bufferMinutes) / Double(Self.preferred)).rounded()))
    }

    /// Each snooze, sized so the whole chain lands on the buffer rather than
    /// running past it.
    var minutes: Int {
        guard count > 0 else { return 0 }
        return max(1, bufferMinutes / count)
    }
}

/// The moments that need more than a notification. A notification is silenced
/// by a Focus and ignored by a sleeping person; an alarm breaks through both,
/// so these are the points where being late actually costs something.
enum AlarmKind: String, CaseIterable, Identifiable, Sendable {
    case wake
    /// The hard stop. Not a setting of its own — it arrives with the wake
    /// alarm and is what stops the snoozing.
    case mustMove
    case leaveHome
    case knockOff

    var id: String { rawValue }

    /// `mustMove` is machinery, not a choice, so it stays out of Setup.
    var isUserFacing: Bool { self != .mustMove }

    static var userFacing: [AlarmKind] { allCases.filter(\.isUserFacing) }

    var label: String {
        switch self {
        case .wake: "Wake up"
        case .mustMove: "Out of bed"
        case .leaveHome: "Leave home"
        case .knockOff: "Knock off"
        }
    }

    var blurb: String {
        switch self {
        case .wake: "At your alarm time. Snoozes run out when your out-of-bed time arrives."
        case .mustMove: "The end of the snoozing, with no way back."
        case .leaveHome: "The moment you have to be out of the door."
        case .knockOff: "Ends the working day, including Friday's earlier one."
        }
    }

    var symbol: String {
        switch self {
        case .wake: "alarm"
        case .mustMove: "bed.double"
        case .leaveHome: "figure.walk.departure"
        case .knockOff: "door.left.hand.open"
        }
    }

    /// Only the wake-up. Snoozing the door just makes you late, and the whole
    /// point of the hard stop is that it cannot be pushed.
    var allowsSnooze: Bool { self == .wake }

    var defaultsKey: String { "alarm.\(rawValue)" }

    /// Off until asked for — an app that starts making noise at 05:45 without
    /// being told to is not a good houseguest.
    var isEnabled: Bool {
        switch self {
        case .mustMove: AlarmKind.wake.isEnabled
        default: UserDefaults.standard.bool(forKey: defaultsKey)
        }
    }

    /// Where this alarm sits in a day's scaffold.
    func minutes(in schedule: DaySchedule) -> Int {
        switch self {
        case .wake: schedule.wake
        case .mustMove: schedule.outOfBed
        case .leaveHome: schedule.leaveHome
        case .knockOff: schedule.knockOff
        }
    }

    /// All of these are anchored to work, so a day off stays quiet. Marking a
    /// weekend as a working day in Setup brings them with it. The hard stop
    /// also needs somewhere to stop: with no buffer there is nothing to cap.
    func applies(to schedule: DaySchedule) -> Bool {
        guard schedule.isWorkday else { return false }
        if self == .mustMove { return schedule.snoozeBuffer >= 2 }
        return true
    }

    /// The anchor on the Today timeline this alarm guards, so the row can show
    /// a bell.
    var anchorID: String {
        switch self {
        case .wake: "wake"
        case .mustMove: "up"
        case .leaveHome: "leave"
        case .knockOff: "knockOff"
        }
    }
}
