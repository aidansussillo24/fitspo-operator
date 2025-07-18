// LocationManager.swift

import Foundation
import CoreLocation

/// Publishes the user’s current location once permission is granted.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @Published var location: CLLocation?      // most recent fix, nil until we get one

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // 1️⃣ Ask the user for “while in use” permission
        manager.requestWhenInUseAuthorization()
        // 2️⃣ Begin delivering location updates
        manager.startUpdatingLocation()
    }

    // Called whenever the auth status changes (iOS 14+)
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            // no-op: we’ll simply never get a location
            break
        default:
            break
        }
    }

    // Called whenever we get a new GPS fix
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        // publish the most recent location
        location = locations.first
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("LocationManager failed:", error.localizedDescription)
    }
}
