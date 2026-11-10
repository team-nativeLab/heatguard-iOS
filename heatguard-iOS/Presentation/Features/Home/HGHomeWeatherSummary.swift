import SwiftUI

struct HGHomeWeatherSummary: View {
    let weather: HomeWeather
    let isCompact: Bool
    let refreshWarningText: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weather.heatLevelTitle)
                            .font(HGFont.bold(10, relativeTo: .caption2))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(HGColor.homeHeatLevelText)
                            .padding(.horizontal, 10)
                            .frame(width: 80, height: 24)
                            .background(HGColor.homeHeatLevelBackground, in: Capsule())
                            .padding(.leading, 23)

                        Text(weather.measurementTitle)
                            .font(HGFont.medium(12, relativeTo: .caption))
                            .padding(.leading, 20)
                            .padding(.top, 16)

                        HStack(alignment: .center, spacing: 8) {
                            Text(weather.temperatureText)
                                .font(HGFont.bold(40, relativeTo: .largeTitle))
                                .fixedSize(horizontal: true, vertical: false)
                            if let deltaText = weather.temperatureDeltaBadgeText {
                                Text(deltaText)
                                    .font(HGFont.bold(9, relativeTo: .caption2))
                                    .foregroundStyle(HGColor.error)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(width: 54, height: 20)
                                    .background(HGColor.homeBaselineBackground, in: Capsule())
                                    .accessibilityLabel(weather.temperatureDeltaText ?? deltaText)
                            }
                        }
                        .padding(.leading, 21)

                        Text("습도 \(weather.humidityText) · 체감온도 \(weather.apparentTemperatureText)")
                            .font(HGFont.regular(12, relativeTo: .caption))
                            .padding(.leading, 20)
                            .padding(.top, 8)
                    }
                    Spacer(minLength: 0)
                    Group {
                        if let assetName = weather.skyIllustrationAssetName(at: timeline.date) {
                            Image(assetName)
                                .resizable()
                                .scaledToFit()
                                .brightness(assetName == "WeatherCloudy" ? -0.07 : 0)
                                .contrast(assetName == "WeatherCloudy" ? 1.04 : 1)
                        } else {
                            Image(systemName: weather.skySymbol(at: timeline.date))
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(weatherSymbolColor(for: weather.skyStatus))
                        }
                    }
                    .frame(width: isCompact ? 120 : 159, height: 121)
                    .offset(y: -2)
                }

                if weather.observationTimeText != nil || weather.observationStatusText != nil {
                    let observationDescription = [
                        weather.observationStatusText,
                        weather.observationTimeText
                    ]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                    Text(observationDescription)
                        .font(HGFont.regular(10, relativeTo: .caption2))
                        .foregroundStyle(weather.observationStatusIsWarning ? Color.orange : HGColor.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.leading, 20)
                        .padding(.top, isCompact ? 2 : 4)
                        .accessibilityLabel("날씨 측정 상태: \(observationDescription)")
                }

                HStack(spacing: 0) {
                    HomeMetric(icon: "HomeHumidity", title: "습도", value: weather.humidityText)
                    Divider().frame(height: 24).padding(.horizontal, 8)
                    HomeMetric(icon: "HomeFeelsLike", title: "체감온도", value: weather.apparentTemperatureText)
                    Divider().frame(height: 24).padding(.horizontal, 8)
                    HomeMetric(
                        symbol: weather.skySymbol(at: timeline.date),
                        symbolColor: weatherSymbolColor(for: weather.skyStatus),
                        title: nil,
                        value: weather.weatherStatusText
                    )
                }
                .padding(.horizontal, 18)
                .frame(height: 78)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                .padding(.horizontal, 26)
                .padding(.top, isCompact ? 10 : 17)

                if let refreshWarningText {
                    Text(refreshWarningText)
                        .font(HGFont.regular(11, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 26)
                        .padding(.top, 8)
                        .accessibilityIdentifier("home.weatherRefreshWarning")
                }
            }
            .padding(.horizontal, -12)
            .foregroundStyle(HGColor.primaryText)
        }
    }

    private func weatherSymbolColor(for skyStatus: String?) -> Color {
        switch skyStatus {
        case "CLEAR": Color(red: 1, green: 0.67, blue: 0.12)
        case "PARTLY_CLOUDY": Color(red: 0.96, green: 0.65, blue: 0.20)
        case "CLOUDY": Color(red: 0.48, green: 0.55, blue: 0.66)
        case "RAIN": Color(red: 0.20, green: 0.52, blue: 0.88)
        case "SNOW": Color(red: 0.36, green: 0.69, blue: 0.91)
        default: Color(red: 1, green: 0.67, blue: 0.12)
        }
    }
}

private struct HomeMetric: View {
    var icon: String?
    var symbol: String?
    var symbolColor: Color?
    let title: String?
    let value: String

    init(
        icon: String? = nil,
        symbol: String? = nil,
        symbolColor: Color? = nil,
        title: String?,
        value: String
    ) {
        self.icon = icon
        self.symbol = symbol
        self.symbolColor = symbolColor
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let symbol {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(symbolColor ?? HGColor.secondaryText)
                } else if let icon {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 20, height: 20)
            .frame(width: 36, height: 36)
            .background(HGColor.homeMetricIconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(HGFont.regular(10, relativeTo: .caption2))
                        .foregroundStyle(HGColor.secondaryText)
                }

                Text(value)
                    .font(HGFont.bold(14, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
