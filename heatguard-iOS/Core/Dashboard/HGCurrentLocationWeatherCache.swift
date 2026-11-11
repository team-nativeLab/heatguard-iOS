import CoreLocation
import Foundation

struct HGCurrentLocationWeatherCacheEntry {
    let coordinate: CLLocationCoordinate2D
    let storedAt: Date
    let weather: HomeWeather

    func isWithinReuseDistance(of coordinate: CLLocationCoordinate2D) -> Bool {
        let storedLocation = CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return storedLocation.distance(from: currentLocation) <= Self.maximumReuseDistance
    }

    func isFresh(asOf date: Date) -> Bool {
        let age = date.timeIntervalSince(storedAt)
        return age >= 0 && age <= Self.maximumAge
    }

    var ageDescription: String {
        let age = max(0, Date().timeIntervalSince(storedAt))
        if age < 60 { return "방금 전 날씨" }
        if age < Self.maximumAge {
            return "\(max(1, Int(age / 60)))분 전 날씨"
        }
        return "\(max(1, Int(age / 3_600)))시간 전 날씨"
    }

    static let maximumAge: TimeInterval = 60 * 60
    static let maximumReuseDistance: CLLocationDistance = 1_000
}

@MainActor
final class HGCurrentLocationWeatherCache {
    static let shared = HGCurrentLocationWeatherCache()

    private var latestEntry: HGCurrentLocationWeatherCacheEntry?

    private init() {}

    func entry(near coordinate: CLLocationCoordinate2D) -> HGCurrentLocationWeatherCacheEntry? {
        guard let latestEntry, latestEntry.isWithinReuseDistance(of: coordinate) else { return nil }
        return latestEntry
    }

    func store(_ weather: HomeWeather, at coordinate: CLLocationCoordinate2D, date: Date = .now) {
        latestEntry = HGCurrentLocationWeatherCacheEntry(
            coordinate: coordinate,
            storedAt: weather.fetchedAt?.hgISO8601Date ?? date,
            weather: weather
        )
    }

    func clear() {
        latestEntry = nil
    }
}
