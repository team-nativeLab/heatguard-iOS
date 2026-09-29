import Foundation

struct HGRecordHistoryService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func fetchRecords(limit: Int = 20, cursor: String? = nil) async throws -> HGRecordPage {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await client.get(
            path: HGAPIPath.teamRecords,
            requiresAuthentication: true,
            queryItems: queryItems
        )
    }

    func fetchDetail(id: String) async throws -> HGRecordDetail {
        try await client.get(
            path: HGAPIPath.teamRecord(id: id),
            requiresAuthentication: true
        )
    }
}

struct HGRecordPage: Decodable {
    let items: [HGRecordHistoryItem]
    let page: HGRecordPageInfo
}

struct HGRecordPageInfo: Decodable {
    let nextCursor: String?
    let hasMore: Bool
}

struct HGRecordHistoryItem: Decodable, Identifiable {
    let recordID: String
    let type: HGRecordType
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let memo: String?
    let measuredAt: String
    let restStartedAt: String?
    let restEndedAt: String?
    let restMinutes: Int?
    let teamName: String?
    let workplace: String?
    let siteName: String?

    enum CodingKeys: String, CodingKey {
        case recordID = "recordId"
        case type
        case temperature
        case humidity
        case apparentTemperature
        case memo
        case measuredAt
        case restStartedAt, restEndedAt, restMinutes, teamName, workplace, siteName
    }

    var id: String { recordID }
}

struct HGRecordDetail: Decodable {
    let recordID: String
    let type: HGRecordType
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let memo: String?
    let measuredAt: String
    let photoURLs: [String]
    let restStartedAt: String?
    let restEndedAt: String?
    let restMinutes: Int?
    let teamName: String?
    let workplace: String?
    let siteName: String?

    enum CodingKeys: String, CodingKey {
        case recordID = "recordId"
        case type
        case temperature
        case humidity
        case apparentTemperature
        case memo
        case measuredAt
        case photoURLs = "photoUrls"
        case restStartedAt, restEndedAt, restMinutes, teamName, workplace, siteName
    }
}

extension HGRecordType {
    var historyTitle: String {
        switch self {
        case .thermometer: "온도계 기록"
        case .work: "작업 사진"
        case .rest: "휴식 사진"
        }
    }
}
