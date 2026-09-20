import Foundation

struct HGChecklistService {
    private let client = HGAPIClient()

    func fetch() async throws -> HGChecklistSummary {
        let times: HGCheckTimesResponse = try await client.get(path: "/api/v1/site/check-times", requiresAuthentication: true)
        guard let token = try HGTeamAccessTokenStore.shared.load() else { throw HGAPIError.authenticationRequired }
        let checklist: HGChecklistResponse = try await client.get(path: "/api/v1/t/\(token)/checklist")
        return HGChecklistSummary(times: times.times, checkedCount: checklist.items.filter(\.checked).count, totalCount: checklist.items.count)
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
private struct HGChecklistItem: Decodable { let checked: Bool }
