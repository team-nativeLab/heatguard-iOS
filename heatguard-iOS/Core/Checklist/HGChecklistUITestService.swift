#if DEBUG
struct HGChecklistUITestService: HGChecklistServicing {
    func fetchItems() async throws -> [HGChecklistItem] {
        [
            HGChecklistItem(id: "item-1", text: "식수(음용수) 비치 확인", checked: true),
            HGChecklistItem(id: "item-2", text: "그늘막·휴게시설 설치 확인", checked: true),
            HGChecklistItem(id: "item-3", text: "근로자 건강상태(온열질환 증상) 확인", checked: false),
            HGChecklistItem(id: "item-4", text: "무더위 시간대(14~17시) 옥외작업 자제", checked: false),
            HGChecklistItem(id: "item-5", text: "2시간마다 20분 이상 휴식 실시", checked: true),
            HGChecklistItem(id: "item-6", text: "응급처치 키트 위치 확인", checked: false)
        ]
    }

    func update(itemID: String, isChecked: Bool) async throws -> HGChecklistUpdateResponse {
        HGChecklistUpdateResponse(itemID: itemID, checked: isChecked, checkedAt: "2026-10-18T00:00:00Z")
    }
}
#endif
