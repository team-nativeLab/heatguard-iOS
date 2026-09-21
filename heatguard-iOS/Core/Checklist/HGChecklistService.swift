import Foundation

struct HGChecklistService {
    private let client = HGAPIClient()

    func fetch() async throws -> HGChecklistSummary {
        let times: HGCheckTimesResponse = try await client.get(path: "/api/v1/site/check-times", requiresAuthentication: true)
        guard let token = try HGTeamAccessTokenStore.shared.load() else { throw HGAPIError.authenticationRequired }
        let checklist: HGChecklistResponse = try await client.get(path: "/api/v1/t/\(token)/checklist")
        return HGChecklistSummary(times: times.times, checkedCount: checklist.items.filter(\.checked).count, totalCount: checklist.items.count)
    }

    func fetchItems() async throws -> [HGChecklistItem] {
        guard let token = try HGTeamAccessTokenStore.shared.load() else { throw HGAPIError.authenticationRequired }
        let response: HGChecklistResponse = try await client.get(path: "/api/v1/t/\(token)/checklist")
        return response.items
    }

    func update(itemID: String, isChecked: Bool) async throws -> HGChecklistItem {
        guard let token = try HGTeamAccessTokenStore.shared.load() else { throw HGAPIError.authenticationRequired }
        return try await client.send(
            HGChecklistUpdateRequest(checked: isChecked),
            method: "PUT",
            path: "/api/v1/t/\(token)/checklist/items/\(itemID)"
        )
    }
}

struct HGChecklistSummary: Equatable {
    let times: [String]
    let checkedCount: Int
    let totalCount: Int
    var statusText: String { "체크리스트 \(checkedCount) / \(totalCount) 완료" }
}

private struct HGCheckTimesResponse: Decodable { let times: [String] }
private struct HGChecklistResponse: Decodable { let items: [HGChecklistItem] }
struct HGChecklistItem: Decodable, Identifiable, Equatable {
    let id: String
    let text: String
    let checked: Bool
    enum CodingKeys: String, CodingKey { case id = "itemId", text, checked }
}
private struct HGChecklistUpdateRequest: Encodable { let checked: Bool }
