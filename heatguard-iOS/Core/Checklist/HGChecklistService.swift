import Foundation

struct HGChecklistService {
    private let client = HGAPIClient()

    func fetch() async throws -> HGChecklistSummary {
        let home: HGWorkerHomeChecklistResponse = try await client.get(
            path: "/api/v1/team",
            requiresAuthentication: true
        )
        let checklist: HGChecklistResponse = try await client.get(
            path: "/api/v1/team/checklist",
            requiresAuthentication: true
        )
        return HGChecklistSummary(times: home.checkTimes, checkedCount: checklist.items.filter(\.checked).count, totalCount: checklist.items.count)
    }

    func fetchItems() async throws -> [HGChecklistItem] {
        let response: HGChecklistResponse = try await client.get(
            path: "/api/v1/team/checklist",
            requiresAuthentication: true
        )
        return response.items
    }

    func update(itemID: String, isChecked: Bool) async throws -> HGChecklistItem {
        return try await client.send(
            HGChecklistUpdateRequest(checked: isChecked),
            method: "PUT",
            path: "/api/v1/team/checklist/items/\(itemID)",
            requiresAuthentication: true
        )
    }
}

struct HGChecklistSummary: Equatable {
    let times: [String]
    let checkedCount: Int
    let totalCount: Int
    var statusText: String { "체크리스트 \(checkedCount) / \(totalCount) 완료" }
}

private struct HGWorkerHomeChecklistResponse: Decodable { let checkTimes: [String] }
private struct HGChecklistResponse: Decodable { let items: [HGChecklistItem] }
struct HGChecklistItem: Decodable, Identifiable, Equatable {
    let id: String
    let text: String
    let checked: Bool
    enum CodingKeys: String, CodingKey { case id = "itemId", text, checked }
}
private struct HGChecklistUpdateRequest: Encodable { let checked: Bool }
