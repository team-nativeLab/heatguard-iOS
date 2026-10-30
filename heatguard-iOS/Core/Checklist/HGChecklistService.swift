import Foundation

struct HGChecklistService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func fetch() async throws -> HGChecklistSummary {
        let home: HGWorkerHomeChecklistResponse = try await client.get(
            path: HGAPIPath.teamHome,
            requiresAuthentication: true
        )
        let checklist: HGChecklistResponse = try await client.get(
            path: HGAPIPath.teamChecklist,
            requiresAuthentication: true
        )
        return HGChecklistSummary(
            times: home.checkTimes ?? [],
            checkedCount: checklist.items.filter(\.checked).count,
            totalCount: checklist.items.count
        )
    }

    func fetchItems() async throws -> [HGChecklistItem] {
        let response: HGChecklistResponse = try await client.get(
            path: HGAPIPath.teamChecklist,
            requiresAuthentication: true
        )
        return response.items
    }

    func update(itemID: String, isChecked: Bool) async throws -> HGChecklistUpdateResponse {
        return try await client.send(
            HGChecklistUpdateRequest(checked: isChecked),
            method: "PUT",
            path: HGAPIPath.teamChecklistItem(id: itemID),
            requiresAuthentication: true
        )
    }

    func fetchRounds(date: String? = nil) async throws -> HGChecklistRounds {
        let response: HGChecklistRounds = try await client.get(
            path: HGAPIPath.teamChecklistRounds,
            requiresAuthentication: true,
            queryItems: date.map { [URLQueryItem(name: "date", value: $0)] } ?? []
        )
        return response
    }

    func fetchRound(id: String, date: String? = nil) async throws -> HGChecklistRound {
        try await client.get(
            path: HGAPIPath.teamChecklistRound(id: id),
            requiresAuthentication: true,
            queryItems: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [],
            pathIsPercentEncoded: true
        )
    }

    func updateRoundItem(
        roundID: String,
        itemID: String,
        isChecked: Bool,
        date: String
    ) async throws -> HGChecklistRoundRefresh {
        let _: HGChecklistRoundItemUpdateResponse = try await client.send(
            HGChecklistUpdateRequest(checked: isChecked),
            method: "PUT",
            path: HGAPIPath.teamChecklistRoundItem(roundID: roundID, itemID: itemID),
            requiresAuthentication: true,
            pathIsPercentEncoded: true
        )
        async let updatedRound = fetchRound(id: roundID, date: date)
        async let updatedRounds = fetchRounds(date: date)
        let refreshedRound = try await updatedRound
        let refreshedRounds = try await updatedRounds
        return HGChecklistRoundRefresh(round: refreshedRound, rounds: refreshedRounds)
    }
}

struct HGChecklistSummary: Equatable {
    let times: [String]
    let checkedCount: Int?
    let totalCount: Int?
    var statusText: String {
        guard let checkedCount, let totalCount else { return "체크리스트 정보 없음" }
        return "체크리스트 \(checkedCount) / \(totalCount) 완료"
    }
}

private struct HGWorkerHomeChecklistResponse: Decodable { let checkTimes: [String]? }
private struct HGChecklistResponse: Decodable { let items: [HGChecklistItem] }

struct HGChecklistRounds: Decodable, Equatable {
    let date: String
    let teamId: String
    let summary: Summary
    let items: [HGChecklistRoundSummary]

    struct Summary: Decodable, Equatable {
        let totalRounds: Int
        let completedRounds: Int
        let missedRounds: Int
        let remainingRounds: Int
        let progressPercent: Int
    }
}

struct HGChecklistRoundSummary: Decodable, Identifiable, Equatable {
    let roundId: String
    let startsAt: String
    let endsAt: String
    let status: HGChecklistRoundStatus
    let totalItems: Int
    let checkedItems: Int
    let progressPercent: Int
    let completedAt: String?

    var id: String { roundId }
}

struct HGChecklistRound: Decodable, Equatable {
    let date: String
    let teamId: String
    let roundId: String
    let startsAt: String
    let endsAt: String
    let status: HGChecklistRoundStatus
    let totalItems: Int
    let checkedItems: Int
    let progressPercent: Int
    let completedAt: String?
    var items: [Item]

    struct Item: Decodable, Identifiable, Equatable {
        let itemId: String
        let text: String
        let sortOrder: Int
        var checked: Bool
        let checkedAt: String?

        var id: String { itemId }
    }

    var isComplete: Bool {
        !items.isEmpty && items.allSatisfy(\.checked)
    }
}

enum HGChecklistRoundStatus: String, Decodable, Equatable {
    case scheduled = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case missed = "MISSED"
}

struct HGChecklistRoundItemUpdateResponse: Decodable, Equatable {
    let date: String
    let roundId: String
    let itemId: String
    let checked: Bool
    let checkedAt: String?
}

struct HGChecklistRoundRefresh {
    let round: HGChecklistRound
    let rounds: HGChecklistRounds
}

enum HGChecklistAPIErrorPresentation {
    static func make(from error: Error) -> HGErrorPresentation {
        guard let apiError = error as? HGAPIError,
              case let .server(message, statusCode, serverCode) = apiError else {
            return HGErrorPresentation(error: error)
        }

        switch (statusCode, serverCode) {
        case (403, "TEAM_MEMBERSHIP_REQUIRED"):
            return HGErrorPresentation(
                title: "팀 권한을 확인해주세요",
                message: "선택된 팀에서 체크리스트를 사용할 권한이 없어요. 팀을 다시 선택한 뒤 시도해주세요.",
                diagnosticCode: diagnostic(statusCode, serverCode)
            )
        case (404, "RESOURCE_NOT_FOUND"):
            return HGErrorPresentation(
                title: "회차 정보를 찾을 수 없습니다",
                message: "회차 또는 체크 항목이 변경됐어요. 목록을 새로고침해주세요.",
                diagnosticCode: diagnostic(statusCode, serverCode)
            )
        case (409, "ROUND_NOT_OPEN"):
            return HGErrorPresentation(
                title: "체크할 수 없는 회차입니다",
                message: "현재 진행 중인 회차에서만 항목을 변경할 수 있어요. 회차 정보를 새로고침해주세요.",
                diagnosticCode: diagnostic(statusCode, serverCode)
            )
        case (400, "VALIDATION_ERROR"):
            return HGErrorPresentation(
                title: "체크 요청을 확인해주세요",
                message: "체크 항목 요청이 올바르지 않아요. 화면을 새로고침한 뒤 다시 시도해주세요.",
                diagnosticCode: diagnostic(statusCode, serverCode)
            )
        default:
            return HGErrorPresentation(
                title: statusCode == 401 ? "로그인이 필요합니다" : "체크리스트 요청 오류",
                message: message,
                diagnosticCode: diagnostic(statusCode, serverCode)
            )
        }
    }

    private static func diagnostic(_ statusCode: Int, _ code: String?) -> String {
        guard let code, !code.isEmpty else { return "HTTP \(statusCode)" }
        return "HTTP \(statusCode) · \(code)"
    }
}

struct HGChecklistItem: Decodable, Identifiable, Equatable {
    let id: String
    let text: String
    let checked: Bool
    enum CodingKeys: String, CodingKey { case id = "itemId", text, checked }
}
private struct HGChecklistUpdateRequest: Encodable { let checked: Bool }

struct HGChecklistUpdateResponse: Decodable, Equatable {
    let itemID: String
    let checked: Bool
    let checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case itemID = "itemId"
        case checked
        case checkedAt
    }
}
