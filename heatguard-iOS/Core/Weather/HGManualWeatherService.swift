import Foundation

struct HGManualWeatherService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func fetch() async throws -> HGManualWeather {
        try await client.get(path: "/api/v1/site/manual-weather", requiresAuthentication: true)
    }

    func save(temperature: Double, humidity: Double, observedAt: Date = .now) async throws -> HGManualWeather {
        try await client.send(
            HGManualWeatherRequest(
                temperature: temperature,
                humidity: humidity,
                observedAt: ISO8601DateFormatter().string(from: observedAt)
            ),
            method: "PUT",
            path: "/api/v1/site/manual-weather",
            requiresAuthentication: true
        )
    }
}

struct HGManualWeather: Decodable {
    let temperature: Double
    let humidity: Double
    let apparentTemperature: Double?
    let heatLevel: String?
    let observedAt: String
}

private struct HGManualWeatherRequest: Encodable {
    let temperature: Double
    let humidity: Double
    let observedAt: String
}
