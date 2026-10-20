import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Setting the circle. Tap the map to move it, or take the current fix if you
/// happen to be standing at work.
struct WorkLocationView: View {
    @Bindable var place: WorkPlace

    @Environment(\.modelContext) private var modelContext
    @State private var service = LocationService.shared
    @State private var camera: MapCameraPosition = .automatic
    @State private var isLocating = false

    private var calendar: Calendar { Clock.calendar }

    var body: some View {
        List {
            Section {
                mapBlock
                    .listRowInsets(EdgeInsets())
                    .frame(height: 240)
            } footer: {
                Text("Tap the map to move the circle. Yetsa notices when you cross into it and says so once a day, on working days only.")
            }

            Section {
                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    Label(isLocating ? "Finding you…" : "Use my current location", systemImage: "location")
                }
                .disabled(isLocating || service.authorization == .denied)

                Stepper(value: $place.radius, in: 100...500, step: 25) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(Int(place.radius)) m")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("A hundred metres is the tightest Apple will reliably fire. Wider is more dependable but triggers further from the door.")
            }

            Section {
                LabeledContent("Location access", value: accessLabel)

                if service.authorization != .authorizedAlways {
                    Button {
                        service.requestAuthorization()
                    } label: {
                        Label("Allow location", systemImage: "location.circle")
                    }
                    .disabled(service.authorization == .denied || service.authorization == .restricted)
                }

                LabeledContent("Watching", value: service.isMonitoring && place.isSet ? "Yes" : "No")

                if let arrival = place.lastArrival {
                    LabeledContent("Last arrival", value: arrivalLabel(arrival))
                }
            } header: {
                Text("Status")
            } footer: {
                Text(accessFooter)
            }

            if place.isSet {
                Section {
                    Button("Forget this place", role: .destructive) {
                        service.stopMonitoring()
                        place.isSet = false
                        place.lastArrival = nil
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("Work location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if place.isSet {
                camera = .region(MKCoordinateRegion(
                    center: place.coordinate,
                    latitudinalMeters: place.radius * 6,
                    longitudinalMeters: place.radius * 6
                ))
            }
        }
        .onChange(of: place.radius) { _, _ in restart() }
    }

    // MARK: - Map

    private var mapBlock: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if place.isSet {
                    MapCircle(center: place.coordinate, radius: place.radius)
                        .foregroundStyle(.primary.opacity(0.12))
                        .stroke(.primary.opacity(0.5), lineWidth: 1.5)

                    Annotation("Work", coordinate: place.coordinate) {
                        Image(systemName: "building.2.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemBackground))
                            .padding(7)
                            .background(.primary, in: .circle)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture { screenPoint in
                guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
                place.coordinate = coordinate
                place.isSet = true
                try? modelContext.save()
                restart()
            }
        }
    }

    // MARK: - Actions

    private func useCurrentLocation() async {
        if service.authorization == .notDetermined {
            service.requestAuthorization()
            return
        }
        isLocating = true
        defer { isLocating = false }

        guard let coordinate = await service.currentLocation() else { return }
        place.coordinate = coordinate
        place.isSet = true
        try? modelContext.save()

        camera = .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: place.radius * 6,
            longitudinalMeters: place.radius * 6
        ))
        restart()
    }

    private func restart() {
        guard place.isSet else { return }
        service.startMonitoring(center: place.coordinate, radius: place.radius)
    }

    // MARK: - Labels

    private var accessLabel: String {
        switch service.authorization {
        case .authorizedAlways: "Always"
        case .authorizedWhenInUse: "While using the app"
        case .denied: "Denied"
        case .restricted: "Restricted"
        default: "Not asked yet"
        }
    }

    private var accessFooter: String {
        switch service.authorization {
        case .authorizedAlways:
            "Yetsa can see the crossing while it is closed, which is the only way this is useful at twenty to eight."
        case .authorizedWhenInUse:
            "While-using is not enough: the crossing happens with the app shut. Allow Always to make this work."
        case .denied, .restricted:
            "Location is off for Yetsa. Turn it on in Settings → Yetsa → Location."
        default:
            "Geofences need location access. Yetsa asks for while-using first, then Always."
        }
    }

    private func arrivalLabel(_ date: Date) -> String {
        calendar.isDateInToday(date)
            ? "\(Clock.clockString(date)) today"
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
