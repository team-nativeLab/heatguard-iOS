import Foundation

struct HGRecordHistoryService {
    private let client = HGAPIClient()

    func fetchRecords() async throws -> [HGRecordHistoryItem] {
        let response: HGRecordHistoryResponse = try await client.get(path: "/api/v1/site/records", requiresAuthentication: true)
        return response.items
    }

    func fetchDetail(id: String) async throws -> HGRecordDetail {
        try await client.get(path: "/api/v1/site/records/\(id)", requiresAuthentication: true)
    }
}

struct HGRecordHistoryItem: Decodable, Identifiable {
    let id: String
    let type: String
    let temperature: Double?
    let measuredAt: String

    enum CodingKeys: String, CodingKey { case id = "recordId", type, temperature, measuredAt }

    var title: String {
        switch type { case "THERMOMETER": "온도계 기록"; case "WORK": "작업 사진"; case "REST": "휴식 사진"; default: "현장 기록" }
    }
}

private struct HGRecordHistoryResponse: Decodable { let items: [HGRecordHistoryItem] }

struct HGRecordDetail: Decodable {
    let type: String
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let memo: String?
    let measuredAt: String
    let photoURLs: [String]
    enum CodingKeys: String, CodingKey { case type, temperature, humidity, apparentTemperature, memo, measuredAt, photoURLs = "photoUrls" }
}
