import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published private(set) var userLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorized || authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        locationManager.requestLocation()
    }

    func distance(to spot: Spot) -> Double? {
        guard let userLocation = userLocation,
              let spotLat = spot.latitude,
              let spotLon = spot.longitude else {
            return nil
        }

        let spotLocation = CLLocation(latitude: spotLat, longitude: spotLon)
        return userLocation.distance(from: spotLocation) // in meters
    }

    func distanceString(to spot: Spot) -> String? {
        guard let meters = distance(to: spot) else { return nil }
        let miles = meters / 1609.344
        if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            userLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorized || authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
