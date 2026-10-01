import Foundation

struct HGWeatherMeasurement {
    let temperature: Double
    let humidity: Double

    init?(temperatureText: String, humidityText: String) {
        guard let temperature = Double(temperatureText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let humidity = Double(humidityText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self.init(temperature: temperature, humidity: humidity)
    }

    init?(temperature: Double, humidity: Double) {
        guard temperature.isFinite, (-50...60).contains(temperature),
              humidity.isFinite, (0...100).contains(humidity) else { return nil }
        self.temperature = temperature
        self.humidity = humidity
    }

    var apparentTemperature: Double {
        // Match the server's KMA summer apparent temperature calculation (°C).
        let wetBulb = temperature * atan(0.151977 * sqrt(humidity + 8.313659))
            + atan(temperature + humidity)
            - atan(humidity - 1.67633)
            + 0.00391838 * pow(humidity, 1.5) * atan(0.023101 * humidity)
            - 4.686035
        let value = -0.2442 + 0.55399 * wetBulb + 0.45535 * temperature
            - 0.0022 * wetBulb * wetBulb + 0.00278 * wetBulb * temperature + 3.0
        return (value * 10).rounded(.toNearestOrEven) / 10
    }
}
