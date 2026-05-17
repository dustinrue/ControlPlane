import CoreLocation
import ControlPlaneSDK

/// Requests and monitors Core Location authorization.
///
/// CoreWLAN operations that need location (reading SSID, scanning networks) are gated
/// by the same TCC permission as CLLocationManager. Requesting authorization here
/// causes macOS to prompt the user and record the grant against our bundle identifier.
final class LocationAuthorizer: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    /// Called once when authorization transitions to granted.
    var onAuthorized: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            log("Location: already authorized", CPLogger.setup)
        case .notDetermined:
            log("Location: requesting authorization", CPLogger.setup)
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            log("Location: denied — Wi-Fi SSID and network scan will be unavailable", CPLogger.setup)
        @unknown default:
            manager.requestAlwaysAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            log("Location: authorized", CPLogger.setup)
            onAuthorized?()
        case .denied, .restricted:
            log("Location: denied — Wi-Fi SSID and network scan will be unavailable", CPLogger.setup)
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
