import Foundation

struct HGDashboardService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func fetchHomeDashboard() async throws -> HomeDashboard {
        let response: WorkerHomeDashboardResponse = try await client.get(
            path: HGAPIPath.teamHome,
            requiresAuthentication: true
        )
        return HomeDashboard(response: response)
    }
}

private struct WorkerHomeDashboardResponse: Decodable {
    let site: WorkerHomeSite?
    let weather: WorkerHomeWeather?
    let heatLevel: Int?
    let checkTimes: [String]?
    let checklistSummary: WorkerChecklistSummary?
}

private struct WorkerHomeSite: Decodable {
    let managerPhone: String?
}

private struct WorkerHomeWeather: Decodable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let heatLevel: Int?
}

private struct WorkerChecklistSummary: Decodable {
    let total: Int?
    let completed: Int?
}

struct HomeDashboard: Equatable {
    let managerPhone: String?
    let weather: HomeWeather
    let checklist: HGChecklistSummary

    fileprivate init(response: WorkerHomeDashboardResponse) {
        managerPhone = response.site?.managerPhone
        weather = HomeWeather(
            temperature: response.weather?.temperature,
            humidity: response.weather?.humidity,
            apparentTemperature: response.weather?.apparentTemperature,
            heatLevel: response.heatLevel ?? response.weather?.heatLevel ?? 0
        )
        checklist = HGChecklistSummary(
            times: response.checkTimes ?? [],
            checkedCount: response.checklistSummary?.completed ?? 0,
            totalCount: response.checklistSummary?.total ?? 0
        )
    }

    static let unavailable = HomeDashboard(
        managerPhone: nil,
        weather: HomeWeather(
            temperature: nil,
            humidity: nil,
            apparentTemperature: nil,
            heatLevel: 0
        ),
        checklist: HGChecklistSummary(times: [], checkedCount: 0, totalCount: 0)
    )

    private init(
        managerPhone: String?,
        weather: HomeWeather,
        checklist: HGChecklistSummary
    ) {
        self.managerPhone = managerPhone
        self.weather = weather
        self.checklist = checklist
    }

}

struct HomeWeather: Equatable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let heatLevel: Int

    var heatLevelTitle: String {
        switch heatLevel {
        case 3: "폭염 위험 단계"
        case 2: "폭염 주의 단계"
        case 1: "폭염 관심 단계"
        default: "폭염 안전 단계"
        }
    }

    var temperatureText: String { measurementText(temperature, suffix: "°C") }
    var humidityText: String { measurementText(humidity, suffix: "%") }
    var apparentTemperatureText: String { measurementText(apparentTemperature, suffix: "°C") }
    var weatherStatusText: String { temperature == nil ? "정보 없음" : "현장 입력" }

    private func measurementText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return "\(String(format: "%.1f", value))\(suffix)"
    }
}
