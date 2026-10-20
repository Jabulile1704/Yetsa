import Foundation
import SwiftData
import CoreLocation

/// Where work is, as a circle on the map. One row, because you have one job.
///
/// Nothing here leaves the phone: the coordinate sits in the same local store
/// as everything else, and the app has no network code at all.
@Model
final class WorkPlace {
    var latitude: Double = 0
    var longitude: Double = 0
    /// Metres. Apple will not reliably fire a geofence much tighter than a
    /// hundred, so that is the floor.
    var radius: Double = 150
    var isSet: Bool = false
    /// What the place is called, so Setup can say more than a radius.
    var name: String = ""
    /// When you last crossed into the circle, so the app can stay quiet for
    /// the rest of the day and compare the real time against the scaffold.
    var lastArrival: Date?

    init() {}

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    /// Whether an arrival has already been recorded for a given day.
    func hasArrived(on day: Date, calendar: Calendar) -> Bool {
        guard let lastArrival else { return false }
        return calendar.isDate(lastArrival, inSameDayAs: day)
    }
}
