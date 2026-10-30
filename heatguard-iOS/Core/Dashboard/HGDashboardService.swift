import Foundation

struct HGDashboardService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) { self.client = client }

    func fetchHomeDashboard() async throws -> HomeDashboard {
        let response: WorkerHomeDashboardResponse = try await client.get(
            path: HGAPIPath.teamHome,
            requiresAuthentication: true
        )
        return HomeDashboard(response: response)
    }
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
    let source: String?
    let sourceName: String?
    let availability: String?
    let isStale: Bool?
    let errorCode: String?
    let skyStatus: String?
    let skySource: String?
    let skyForecastAt: String?
    let comparisonObservedAt: String?
    let comparisonBasis: String?
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
        weather = HomeWeather(response: response.weather)
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
}

struct HomeWeather: Equatable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let heatLevel: Double?
    let temperatureDelta: Double?
    let comparisonTemperature: Double?
    let observedAt: String?
    let fetchedAt: String?
    let source: String?
    let sourceName: String?
    let availability: String?
    let isStale: Bool?
    let errorCode: String?
    let skyStatus: String?
    let skySource: String?
    let skyForecastAt: String?
    let comparisonObservedAt: String?
    let comparisonBasis: String?

    init(
        temperature: Double?, humidity: Double?, apparentTemperature: Double?, heatLevel: Double?,
        temperatureDelta: Double?, comparisonTemperature: Double?, observedAt: String?,
        fetchedAt: String? = nil, source: String? = nil, sourceName: String? = nil,
        availability: String? = nil, isStale: Bool? = nil, errorCode: String? = nil,
        skyStatus: String?, skySource: String? = nil, skyForecastAt: String? = nil,
        comparisonObservedAt: String?, comparisonBasis: String?
    ) {
        self.temperature = availability == "UNAVAILABLE" ? nil : temperature
        self.humidity = availability == "UNAVAILABLE" ? nil : humidity
        self.apparentTemperature = availability == "UNAVAILABLE" ? nil : apparentTemperature
        self.heatLevel = availability == "UNAVAILABLE" ? nil : heatLevel
        self.temperatureDelta = temperatureDelta
        self.comparisonTemperature = comparisonTemperature
        self.observedAt = observedAt
        self.fetchedAt = fetchedAt
        self.source = source
        self.sourceName = sourceName
        self.availability = availability
        self.isStale = isStale
        self.errorCode = errorCode
        self.skyStatus = skyStatus
        self.skySource = skySource
        self.skyForecastAt = skyForecastAt
        self.comparisonObservedAt = comparisonObservedAt
        self.comparisonBasis = comparisonBasis
    }

    init(response: WorkerHomeWeather?) {
        self.init(
            temperature: response?.temperature,
            humidity: response?.humidity,
            apparentTemperature: response?.apparentTemperature,
            heatLevel: response?.heatLevel,
            temperatureDelta: response?.temperatureDelta,
            comparisonTemperature: response?.comparisonTemperature,
            observedAt: response?.observedAt,
            fetchedAt: response?.fetchedAt,
            source: response?.source,
            sourceName: response?.sourceName,
            availability: response?.availability,
            isStale: response?.isStale,
            errorCode: response?.errorCode,
            skyStatus: response?.skyStatus,
            skySource: response?.skySource,
            skyForecastAt: response?.skyForecastAt,
            comparisonObservedAt: response?.comparisonObservedAt,
            comparisonBasis: response?.comparisonBasis
        )
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

    var apparentTemperatureText: String {
        measurementText(apparentTemperature ?? calculatedApparentTemperature, suffix: "°C")
    }

    var weatherStatusText: String {
        switch skyStatus {
        case "CLEAR": "맑음"
        case "PARTLY_CLOUDY": "구름 조금"
        case "CLOUDY": "흐림"
        case "RAIN": "비"
        case "SNOW": "눈"
        default: "정보 없음"
        }
    }

    var skySymbol: String {
        switch skyStatus {
        case "CLEAR": "sun.max.fill"
        case "PARTLY_CLOUDY": "cloud.sun.fill"
        case "CLOUDY": "cloud.fill"
        case "RAIN": "cloud.rain.fill"
        case "SNOW": "cloud.snow.fill"
        default: "cloud.questionmark.fill"
        }
    }

    var skyIllustrationAssetName: String? {
        switch skyStatus {
        case "CLEAR": "WeatherSunny"
        case "PARTLY_CLOUDY", .none: "WeatherPartlyCloudy"
        default: nil
        }
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
            || (source == "MANUAL" && observationStatusText == "이전 날짜의 수동 측정값")
    }

    static let unavailable = HomeWeather(
        temperature: nil, humidity: nil, apparentTemperature: nil, heatLevel: nil,
        temperatureDelta: nil, comparisonTemperature: nil, observedAt: nil, fetchedAt: nil,
        source: nil, sourceName: nil, availability: "UNAVAILABLE", isStale: false, errorCode: nil,
        skyStatus: nil, skySource: nil, skyForecastAt: nil,
        comparisonObservedAt: nil, comparisonBasis: nil
    )

    private func measurementText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return "\(String(format: "%.1f", value))\(suffix)"
    }
}
