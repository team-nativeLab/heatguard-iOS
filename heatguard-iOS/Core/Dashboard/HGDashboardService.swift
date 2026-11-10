import Foundation
import OSLog

struct HGDashboardService {
    private static let weatherLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HeatGuard",
        category: "WeatherResponse"
    )

    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) { self.client = client }

    func fetchHomeDashboard() async throws -> HomeDashboard {
        let response: WorkerHomeDashboardResponse = try await client.get(
            path: HGAPIPath.teamHome,
            requiresAuthentication: true
        )
        if let weather = response.weather {
            Self.logWeatherResponse(weather, source: "team-dashboard")
        }
        return HomeDashboard(response: response)
    }

    func fetchCurrentLocationWeather(latitude: Double, longitude: Double) async throws -> HomeWeather {
        let response: WorkerHomeWeather = try await client.send(
            HGCurrentWeatherRequest(latitude: latitude, longitude: longitude),
            method: "POST",
            path: HGAPIPath.teamWeather,
            requiresAuthentication: true,
            timeoutInterval: 90
        )
        Self.logWeatherResponse(response, source: "location")
        return response.homeWeather
    }

    private static func logWeatherResponse(_ weather: WorkerHomeWeather, source: String) {
        weatherLogger.info("""
            Weather decoded source=\(source, privacy: .public)
            availability=\(weather.availability ?? "nil", privacy: .public)
            errorCode=\(weather.errorCode ?? "none", privacy: .public)
            """)
        weatherLogger.info("""
            Weather values temperaturePresent=\(weather.temperature != nil)
            humidityPresent=\(weather.humidity != nil)
            skyStatus=\(weather.skyStatus ?? "nil", privacy: .public)
            weatherSource=\(weather.source ?? "nil", privacy: .public)
            """)
    }
}

private struct HGCurrentWeatherRequest: Encodable {
    let latitude: Double
    let longitude: Double
}

private struct WorkerHomeDashboardResponse: Decodable {
    let company: WorkerHomeCompany?
    let site: WorkerHomeSite?
    let team: WorkerHomeTeam?
    let weather: WorkerHomeWeather?
    let checkTimes: [String]?
    let checklistSummary: WorkerChecklistSummary?
    let unreadNotificationCount: Int?
}

private struct WorkerHomeCompany: Decodable { let name: String?; let phone: String? }
private struct WorkerHomeSite: Decodable { let name: String?; let managerPhone: String? }
private struct WorkerHomeTeam: Decodable { let name: String?; let workplace: String? }

struct WorkerHomeWeather: Decodable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let heatLevel: Double?
    let temperatureDelta: Double?
    let comparisonTemperature: Double?
    let observedAt: String?
    let fetchedAt: String?
    let coldWaveWarning: HGColdWaveWarning?
    let skyStatus: String?
    let comparisonObservedAt: String?
    let comparisonBasis: String?
    let availability: String?
    let errorCode: String?
    let isStale: Bool?
    let source: String?
    let sourceName: String?
    let skySource: String?
    let skyForecastAt: String?

    var homeWeather: HomeWeather {
        HomeWeather(
            temperature: temperature,
            humidity: humidity,
            apparentTemperature: apparentTemperature,
            heatLevel: heatLevel,
            temperatureDelta: temperatureDelta,
            comparisonTemperature: comparisonTemperature,
            observedAt: observedAt,
            skyStatus: skyStatus,
            comparisonObservedAt: comparisonObservedAt,
            comparisonBasis: comparisonBasis,
            availability: availability,
            errorCode: errorCode,
            isStale: isStale,
            source: source,
            sourceName: sourceName,
            skySource: skySource,
            skyForecastAt: skyForecastAt,
            fetchedAt: fetchedAt,
            coldWaveWarning: coldWaveWarning
        )
    }
}

struct HGColdWaveWarning: Decodable, Equatable {
    let level: String?
    let availability: String?
    let areaCode: String?
    let areaName: String?
    let issuedAt: String?
    let effectiveAt: String?
    let fetchedAt: String?
    let isStale: Bool?
    let errorCode: String?
    let source: String?

    var badgeText: String? {
        if availability == "LOCATION_REQUIRED" { return "한파 위치 정보 없음" }
        guard availability == "AVAILABLE" || availability == "CACHED" else {
            return "한파 정보 확인 불가"
        }

        let title: String
        switch level {
        case "ADVISORY": title = "한파주의보"
        case "WARNING": title = "한파경보"
        case "NONE":
            guard availability == "CACHED" || isStale == true else { return nil }
            title = "한파 특보 없음"
        default: title = "한파 정보 확인 불가"
        }

        guard availability == "CACHED" || isStale == true else { return title }
        let time = fetchedAt?.hgISO8601Date.map {
            HGDateFormatting.string(from: $0, format: "HH:mm")
        }
        return "\(title) · 이전 정보" + (time.map { " · \($0)" } ?? "")
    }

    var isActive: Bool { level == "ADVISORY" || level == "WARNING" }
}

private struct WorkerChecklistSummary: Decodable { let total: Int?; let completed: Int? }

struct HomeDashboard: Equatable {
    let companyName: String?
    let companyPhone: String?
    let managerPhone: String?
    let siteName: String?
    let teamName: String?
    let workplace: String?
    let weather: HomeWeather
    let checklist: HGChecklistSummary
    let unreadNotificationCount: Int

    fileprivate init(response: WorkerHomeDashboardResponse) {
        companyName = response.company?.name
        companyPhone = response.company?.phone
        managerPhone = response.site?.managerPhone
        siteName = response.site?.name
        teamName = response.team?.name
        workplace = response.team?.workplace
        weather = response.weather?.homeWeather ?? .unavailable
        checklist = HGChecklistSummary(
            times: response.checkTimes ?? [],
            checkedCount: response.checklistSummary?.completed,
            totalCount: response.checklistSummary?.total
        )
        unreadNotificationCount = max(0, response.unreadNotificationCount ?? 0)
    }

    static let unavailable = HomeDashboard(
        companyName: nil,
        companyPhone: nil,
        managerPhone: nil,
        siteName: nil,
        teamName: nil,
        workplace: nil,
        weather: .unavailable,
        checklist: HGChecklistSummary(times: [], checkedCount: nil, totalCount: nil),
        unreadNotificationCount: 0
    )

    init(
        companyName: String?, companyPhone: String?, managerPhone: String?, siteName: String?,
        teamName: String?, workplace: String?, weather: HomeWeather,
        checklist: HGChecklistSummary, unreadNotificationCount: Int
    ) {
        self.companyName = companyName
        self.companyPhone = companyPhone
        self.managerPhone = managerPhone
        self.siteName = siteName
        self.teamName = teamName
        self.workplace = workplace
        self.weather = weather
        self.checklist = checklist
        self.unreadNotificationCount = unreadNotificationCount
    }

    func replacingWeather(_ weather: HomeWeather) -> HomeDashboard {
        HomeDashboard(
            companyName: companyName,
            companyPhone: companyPhone,
            managerPhone: managerPhone,
            siteName: siteName,
            teamName: teamName,
            workplace: workplace,
            weather: weather,
            checklist: checklist,
            unreadNotificationCount: unreadNotificationCount
        )
    }
}

struct HomeWeather: Equatable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let heatLevel: Double?
    let temperatureDelta: Double?
    let comparisonTemperature: Double?
    let observedAt: String?
    let skyStatus: String?
    let comparisonObservedAt: String?
    let comparisonBasis: String?
    let availability: String?
    let errorCode: String?
    let isStale: Bool?
    let source: String?
    let sourceName: String?
    let skySource: String?
    let skyForecastAt: String?
    let fetchedAt: String?
    let coldWaveWarning: HGColdWaveWarning?

    init(
        temperature: Double?, humidity: Double?, apparentTemperature: Double?, heatLevel: Double?,
        temperatureDelta: Double?, comparisonTemperature: Double?, observedAt: String?, skyStatus: String?,
        comparisonObservedAt: String?, comparisonBasis: String?, availability: String? = nil,
        errorCode: String? = nil, isStale: Bool? = nil, source: String? = nil,
        sourceName: String? = nil, skySource: String? = nil, skyForecastAt: String? = nil,
        fetchedAt: String? = nil, coldWaveWarning: HGColdWaveWarning? = nil
    ) {
        self.temperature = availability == "UNAVAILABLE" ? nil : temperature
        self.humidity = availability == "UNAVAILABLE" ? nil : humidity
        self.apparentTemperature = availability == "UNAVAILABLE" ? nil : apparentTemperature
        self.heatLevel = availability == "UNAVAILABLE" ? nil : heatLevel
        self.temperatureDelta = availability == "UNAVAILABLE" ? nil : temperatureDelta
        self.comparisonTemperature = availability == "UNAVAILABLE" ? nil : comparisonTemperature
        self.observedAt = observedAt
        self.skyStatus = skyStatus
        self.comparisonObservedAt = comparisonObservedAt
        self.comparisonBasis = comparisonBasis
        self.availability = availability
        self.errorCode = errorCode
        self.isStale = isStale
        self.source = source
        self.sourceName = sourceName
        self.skySource = skySource
        self.skyForecastAt = skyForecastAt
        self.fetchedAt = fetchedAt
        self.coldWaveWarning = coldWaveWarning
    }

    var measurementTitle: String { source == "MANUAL" ? "최근 측정 온도" : "현재 온도" }

    var heatLevelTitle: String {
        if availability == "UNAVAILABLE" { return "폭염 정보 없음" }
        if observationStatusIsWarning { return "측정값 갱신 필요" }
        return switch heatLevel {
        case let value? where value >= 3: "폭염 위험 단계"
        case let value? where value >= 2: "폭염 주의 단계"
        case let value? where value >= 1: "폭염 관심 단계"
        case .some: "폭염 안전 단계"
        case .none: "폭염 단계 정보 없음"
        }
    }

    var temperatureText: String { measurementText(temperature, suffix: "°C") }
    var humidityText: String { measurementText(humidity, suffix: "%") }
    var calculatedApparentTemperature: Double? {
        guard let temperature, let humidity else { return nil }
        return HGWeatherMeasurement(temperature: temperature, humidity: humidity)?.apparentTemperature
    }

    var displayedApparentTemperature: Double? {
        apparentTemperature ?? calculatedApparentTemperature
    }

    var apparentTemperatureText: String { measurementText(displayedApparentTemperature, suffix: "°C") }

    var weatherStatusText: String {
        if source == "MANUAL", skyStatus == nil { return "정보 없음" }
        return switch skyStatus {
        case "CLEAR": "맑음"
        case "PARTLY_CLOUDY": "구름"
        case "CLOUDY": "흐림"
        case "RAIN": "비"
        case "SNOW": "눈"
        default:
            switch availability {
            case "UNAVAILABLE": "정보 없음"
            case "CACHED": "이전 정보"
            case "AVAILABLE": "확인 중"
            default: "정보 없음"
            }
        }
    }

    var skySymbol: String {
        switch skyStatus {
        case "CLEAR": "sun.max.fill"
        case "PARTLY_CLOUDY": "cloud.sun.fill"
        case "CLOUDY": "cloud.fill"
        case "RAIN": "cloud.rain.fill"
        case "SNOW": "cloud.snow.fill"
        default: "sun.max.fill"
        }
    }

    func skySymbol(at date: Date) -> String {
        guard skyStatus == "CLEAR", isNight(at: date) else { return skySymbol }
        return "moon.fill"
    }

    var skyIllustrationAssetName: String? {
        switch skyStatus {
        case "CLEAR": "WeatherSunny"
        case "PARTLY_CLOUDY": "WeatherPartlyCloudy"
        case "CLOUDY": "WeatherCloudy"
        case "RAIN": "WeatherRain"
        case "SNOW": "WeatherSnow"
        default: "WeatherSunny"
        }
    }

    func skyIllustrationAssetName(at date: Date) -> String? {
        guard skyStatus == "CLEAR", isNight(at: date) else { return skyIllustrationAssetName }
        return "WeatherClearNight"
    }

    private func isNight(at date: Date) -> Bool {
        let hour = HGDateFormatting.calendar.component(.hour, from: date)
        return hour >= 18 || hour < 6
    }

    var temperatureDeltaText: String? {
        guard let temperatureDelta else { return nil }
        let sign = temperatureDelta > 0 ? "+" : ""
        var details: [String] = []
        if let comparisonTemperature {
            details.append("이전 \(String(format: "%.1f", comparisonTemperature))°C")
        }
        if let comparisonDate = comparisonObservedAt?.hgISO8601Date {
            details.append("\(HGDateFormatting.string(from: comparisonDate, format: "HH:mm")) 기준")
        }
        let reference = details.isEmpty ? "" : " · " + details.joined(separator: " · ")
        let title = comparisonBasis == "PREVIOUS_OBSERVATION" ? "직전 측정 대비" : "온도 변화"
        return "\(title) \(sign)\(String(format: "%.1f", temperatureDelta))°C\(reference)"
    }

    var temperatureDeltaBadgeText: String? {
        guard let temperatureDelta else { return nil }
        let direction = temperatureDelta > 0 ? "▲" : temperatureDelta < 0 ? "▼" : "•"
        let sign = temperatureDelta > 0 ? "+" : ""
        return "\(direction) \(sign)\(String(format: "%.1f", temperatureDelta))°C"
    }

    var observationTimeText: String? {
        guard let observedDate = observedAt?.hgISO8601Date else { return nil }
        let label = source == "MANUAL" ? "마지막 수동 측정" : "측정"
        return "\(label) \(HGDateFormatting.timestamp(observedDate))"
    }

    var observationStatusText: String? {
        observationStatusText(asOf: .now)
    }

    func observationStatusText(asOf now: Date) -> String? {
        if availability == "UNAVAILABLE" { return "현재 날씨 관측값이 없어요" }
        if isStale == true || availability == "CACHED" { return "최근 관측값 · 갱신 지연" }
        guard source == "MANUAL", let observedDate = observedAt?.hgISO8601Date else { return nil }
        let observedDay = HGDateFormatting.calendar.startOfDay(for: observedDate)
        let today = HGDateFormatting.calendar.startOfDay(for: now)
        return observedDay < today ? "이전 날짜의 수동 측정값" : "현장 수동 입력값"
    }

    var observationStatusIsWarning: Bool {
        availability == "UNAVAILABLE"
            || isStale == true
            || availability == "CACHED"
            || observationStatusText == "이전 날짜의 수동 측정값"
    }

    static let unavailable = HomeWeather(
        temperature: nil, humidity: nil, apparentTemperature: nil, heatLevel: nil,
        temperatureDelta: nil, comparisonTemperature: nil, observedAt: nil,
        skyStatus: nil, comparisonObservedAt: nil, comparisonBasis: nil
    )

    private func measurementText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return "\(String(format: "%.1f", value))\(suffix)"
    }
}
