import Foundation

struct HGNotificationService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) { self.client = client }

    func fetch(category: HGNotificationCategory, cursor: String? = nil, limit: Int = 20) async throws -> HGNotificationPage {
        var query = [
            URLQueryItem(name: "category", value: category.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await client.get(path: HGAPIPath.teamNotifications, requiresAuthentication: true, queryItems: query)
    }

    func markRead(id: String) async throws {
        try await client.sendVoid(method: "PATCH", path: HGAPIPath.teamNotificationRead(id: id), requiresAuthentication: true)
    }
}

enum HGNotificationCategory: String, Decodable, CaseIterable, Identifiable {
    case all = "ALL"
    case record = "RECORD"
    case emergency = "EMERGENCY"
    case notice = "NOTICE"

    var id: Self { self }
    var title: String {
        switch self {
        case .all: "전체"
        case .record: "기록"
        case .emergency: "긴급"
        case .notice: "공지"
        }
    }
}

struct HGNotificationPage: Decodable {
    let items: [HGNotification]
    let page: HGNotificationPageInfo
    let unreadCount: Int
    let filteredUnreadCount: Int
}

struct HGNotificationPageInfo: Decodable {
    let nextCursor: String?
    let hasMore: Bool
}

struct HGNotification: Decodable, Identifiable {
    let notificationID: String
    let title: String
    let resourceID: String
    let createdAt: String
    let type: HGNotificationType
    let category: HGNotificationCategory
    let read: Bool

    var id: String { notificationID }

    enum CodingKeys: String, CodingKey {
        case notificationID = "notificationId"
        case title, createdAt, type, category, read
        case resourceID = "resourceId"
    }
}

enum HGNotificationType: Equatable, Decodable {
    case recordCreated
    case emergencyAcknowledged
    case inquiryAnswered
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "RECORD_CREATED": self = .recordCreated
        case "EMERGENCY_ACKNOWLEDGED": self = .emergencyAcknowledged
        case "INQUIRY_ANSWERED": self = .inquiryAnswered
        default: self = .unknown(value)
        }
    }
}
