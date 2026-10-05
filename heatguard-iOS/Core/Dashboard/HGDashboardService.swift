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

private struct WorkerHomeWeather: Decodable {
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
        let source = response.weather
        weather = HomeWeather(
            temperature: source?.temperature,
            humidity: source?.humidity,
            apparentTemperature: source?.apparentTemperature,
            heatLevel: source?.heatLevel,
            temperatureDelta: source?.temperatureDelta,
            comparisonTemperature: source?.comparisonTemperature,
            observedAt: source?.observedAt,
            skyStatus: source?.skyStatus,
            comparisonObservedAt: source?.comparisonObservedAt,
            comparisonBasis: source?.comparisonBasis
        )
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

    private init(
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
    let skyStatus: String?
    let comparisonObservedAt: String?
    let comparisonBasis: String?

    var heatLevelTitle: String {
        switch heatLevel {
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

    var apparentTemperatureText: String { measurementText(calculatedApparentTemperature, suffix: "°C") }

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
            details.append("\(comparisonDate.formatted(date: .omitted, time: .shortened)) 기준")
        }
        let reference = details.isEmpty ? "" : " · " + details.joined(separator: " · ")
        let title = comparisonBasis == "PREVIOUS_OBSERVATION" ? "직전 측정 대비" : "온도 변화"
        return "\(title) \(sign)\(String(format: "%.1f", temperatureDelta))°C\(reference)"
    }

    var observationTimeText: String? {
        guard let observedDate = observedAt?.hgISO8601Date else { return nil }
        return "측정 \(observedDate.formatted(date: .numeric, time: .shortened))"
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
