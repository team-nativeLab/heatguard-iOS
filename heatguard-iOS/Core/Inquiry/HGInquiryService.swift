import Foundation

struct HGInquiryService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func fetchInquiries(
        status: HGInquiryStatus? = nil,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> HGInquiryPage {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        return try await client.get(
            path: HGAPIPath.teamInquiries,
            requiresAuthentication: true,
            queryItems: queryItems
        )
    }

    func createInquiry(title: String, content: String) async throws -> HGInquiryCreationResult {
        try await client.send(
            HGInquiryCreationRequest(title: title, content: content),
            method: "POST",
            path: HGAPIPath.teamInquiries,
            requiresAuthentication: true
        )
    }

    func fetchInquiry(id: String) async throws -> HGInquiryDetail {
        try await client.get(path: HGAPIPath.teamInquiry(id: id), requiresAuthentication: true)
    }
}

struct HGInquiryPage: Decodable {
    let items: [HGInquirySummary]
    let page: HGInquiryPageInfo
}

struct HGInquiryPageInfo: Decodable {
    let nextCursor: String?
    let hasMore: Bool
}

enum HGInquiryStatus: String, Decodable, CaseIterable, Identifiable {
    case open = "OPEN"
    case answered = "ANSWERED"
    case closed = "CLOSED"

    var id: Self { self }

    var title: String {
        switch self {
        case .open: "답변 대기"
        case .answered: "답변 완료"
        case .closed: "종료"
        }
    }
}

struct HGInquirySummary: Decodable, Identifiable {
    let inquiryID: String
    let title: String
    let content: String
    let status: HGInquiryStatus
    let deliveryStatus: String
    let createdAt: String

    var id: String { inquiryID }

    enum CodingKeys: String, CodingKey {
        case inquiryID = "inquiryId"
        case title, content, status, deliveryStatus, createdAt
    }
}

struct HGInquiryDetail: Decodable {
    let inquiryID: String
    let title: String
    let content: String
    let status: HGInquiryStatus
    let createdAt: String
    let replies: [HGInquiryReply]

    enum CodingKeys: String, CodingKey {
        case inquiryID = "inquiryId"
        case title, content, status, createdAt, replies
    }
}

struct HGInquiryReply: Decodable, Identifiable {
    let replyID: String
    let content: String
    let answeredAt: String?

    var id: String { replyID }

    enum CodingKeys: String, CodingKey {
        case replyID = "replyId"
        case content, answeredAt
    }
}

struct HGInquiryCreationResult: Decodable {
    let inquiryID: String
    let status: HGInquiryStatus
    let deliveryStatus: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case inquiryID = "inquiryId"
        case status, deliveryStatus, createdAt
    }
}

private struct HGInquiryCreationRequest: Encodable {
    let title: String
    let content: String
}
