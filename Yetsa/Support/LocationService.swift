import Foundation
import CoreLocation
import Observation

/// Watches a single circle on the map and says when you cross into it.
///
/// Uses `CLMonitor` rather than the old region-monitoring calls, which Apple
/// has marked for deprecation. The monitor is persistent: iOS keeps it across
/// launches and wakes the app to deliver a crossing, which is the whole point
/// — you will not have Yetsa open at twenty to eight.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private static let monitorName = "YetsaPlaces"
    private static let workIdentifier = "work"

    private let manager = CLLocationManager()
    private var monitor: CLMonitor?
    private var watching: Task<Void, Never>?
    private var pendingFix: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    /// Called when you cross into the circle. The app decides what that means.
    var onArrive: ((Date) -> Void)?

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var isMonitoring = false

    override private init() {
        super.init()
        manager.delegate = self
        authorization = manager.authorizationStatus
    }

    // MARK: - Permission

    /// Geofences only fire in the background with Always. iOS asks for
    /// When In Use first and offers to upgrade later, so this asks in that
    /// order rather than demanding everything at once.
    func requestAuthorization() {
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    var canMonitorInBackground: Bool {
        authorization == .authorizedAlways
    }

    // MARK: - One-off fix

    /// A single reading, for the "use my current location" button.
    func currentLocation() async -> CLLocationCoordinate2D? {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            pendingFix = continuation
            manager.requestLocation()
        }
    }

    // MARK: - Monitoring

    func startMonitoring(center: CLLocationCoordinate2D, radius: Double) {
        watching?.cancel()
        watching = Task { [weak self] in
            guard let self else { return }
            let monitor = await CLMonitor(Self.monitorName)
            self.monitor = monitor

            // Replace whatever was there: the circle may have moved.
            for identifier in await monitor.identifiers {
                await monitor.remove(identifier)
            }

            let condition = CLMonitor.CircularGeographicCondition(
                center: center,
                radius: max(100, radius)
            )
            await monitor.add(condition, identifier: Self.workIdentifier)
            self.isMonitoring = true

            do {
                for try await event in await monitor.events {
                    guard event.identifier == Self.workIdentifier else { continue }
                    if event.state == .satisfied {
                        self.onArrive?(event.date)
                    }
                }
            } catch {
                self.isMonitoring = false
            }
        }
    }

    func stopMonitoring() {
        watching?.cancel()
        watching = nil
        isMonitoring = false
        Task { [monitor] in
            guard let monitor else { return }
            for identifier in await monitor.identifiers {
                await monitor.remove(identifier)
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            self.pendingFix?.resume(returning: coordinate)
            self.pendingFix = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.pendingFix?.resume(returning: nil)
            self.pendingFix = nil
        }
    }
}
