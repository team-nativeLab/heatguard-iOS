import CoreLocation
import Foundation

@MainActor
final class HGCurrentLocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = HGCurrentLocationProvider()

    private enum LocationError: Error {
        case servicesDisabled
        case permissionDenied
        case locationUnavailable
        case requestInProgress
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var isWaitingForAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var canUseCachedWeatherRefresh: Bool {
        CLLocationManager.locationServicesEnabled()
            && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways)
    }

    func currentCoordinate() async throws -> CLLocationCoordinate2D {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.servicesDisabled
        }
        guard continuation == nil else {
            throw LocationError.requestInProgress
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) in
                self.continuation = continuation
                switch manager.authorizationStatus {
                case .notDetermined:
                    isWaitingForAuthorization = true
                    manager.requestWhenInUseAuthorization()
                case .authorizedWhenInUse, .authorizedAlways:
                    manager.requestLocation()
                case .denied, .restricted:
                    finish(with: .failure(LocationError.permissionDenied))
                @unknown default:
                    finish(with: .failure(LocationError.permissionDenied))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(with: .failure(CancellationError()))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isWaitingForAuthorization else { return }
        isWaitingForAuthorization = false

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .failure(LocationError.permissionDenied))
        case .notDetermined:
            break
        @unknown default:
            finish(with: .failure(LocationError.permissionDenied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last(where: {
            $0.horizontalAccuracy >= 0 && CLLocationCoordinate2DIsValid($0.coordinate)
        }) else {
            finish(with: .failure(LocationError.locationUnavailable))
            return
        }
        finish(with: .success(location.coordinate))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: .failure(error))
    }

    private func finish(with result: Result<CLLocationCoordinate2D, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        isWaitingForAuthorization = false
        continuation.resume(with: result)
    }
}
