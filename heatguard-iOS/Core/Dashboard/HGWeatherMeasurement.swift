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
        // NWS heat index uses Fahrenheit and returns Fahrenheit. Convert back to Celsius.
        let fahrenheit = temperature * 9 / 5 + 32
        let simple = 0.5 * (fahrenheit + 61 + (fahrenheit - 68) * 1.2 + humidity * 0.094)
        let averaged = (simple + fahrenheit) / 2
        var heatIndex = averaged

        if averaged >= 80 {
            let t = fahrenheit
            let rh = humidity
            heatIndex = -42.379 + 2.04901523 * t + 10.14333127 * rh
                - 0.22475541 * t * rh - 0.00683783 * t * t - 0.05481717 * rh * rh
                + 0.00122874 * t * t * rh + 0.00085282 * t * rh * rh
                - 0.00000199 * t * t * rh * rh

            if rh < 13, (80...112).contains(t) {
                heatIndex -= (13 - rh) / 4 * sqrt((17 - abs(t - 95)) / 17)
            } else if rh > 85, (80...87).contains(t) {
                heatIndex += (rh - 85) / 10 * (87 - t) / 5
            }
        }

        return ((heatIndex - 32) * 5 / 9 * 10).rounded() / 10
    }
}
