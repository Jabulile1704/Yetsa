import Foundation
import SwiftData

/// A tick. `forDay` is the day it counts towards, which is not always the day
/// it was tapped — ticking last night's dishes at 00:20 still belongs to
/// yesterday as far as a streak is concerned.
@Model
final class Completion {
    var completedAt: Date = Date.now
    var forDay: Date = Date.now
    /// What it really took, in minutes. Zero means nobody measured.
    var actualMinutes: Int = 0
    /// A deliberate skip, not a miss. Skips keep the rhythm and stay out of
    /// quota counts.
    var wasSkipped: Bool = false

    var task: TaskItem?

    init(forDay: Date, completedAt: Date = .now, actualMinutes: Int = 0, wasSkipped: Bool = false) {
        self.forDay = forDay
        self.completedAt = completedAt
        self.actualMinutes = actualMinutes
        self.wasSkipped = wasSkipped
    }
}
