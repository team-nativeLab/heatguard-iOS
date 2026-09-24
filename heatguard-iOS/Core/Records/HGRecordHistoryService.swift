import Foundation

struct HGRecordHistoryService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func fetchRecords() async throws -> HGRecordPage {
        try await client.get(
            path: "/api/v1/team/records",
            requiresAuthentication: true
        )
    }

    func fetchDetail(id: String) async throws -> HGRecordDetail {
        try await client.get(
            path: "/api/v1/team/records/\(id)",
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

    enum CodingKeys: String, CodingKey {
        case recordID = "recordId"
        case type
        case temperature
        case humidity
        case apparentTemperature
        case memo
        case measuredAt
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

    enum CodingKeys: String, CodingKey {
        case recordID = "recordId"
        case type
        case temperature
        case humidity
        case apparentTemperature
        case memo
        case measuredAt
        case photoURLs = "photoUrls"
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
