import SwiftUI

struct AppLinkedSiteDashboardView: View {
    let site: HGAppSite
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var dashboard: HGLinkedSiteDashboard?
    @State private var error: HGErrorPresentation?
    @State private var loading = false
    private let service = HGAppSiteLinkingService()

    var body: some View {
        List {
            if let error {
                Section {
                    Text(error.alertMessage)
                    Button("다시 불러오기") { Task { await load() } }
                }
            } else if let dashboard {
                Section("오늘의 현장") {
                    LabeledContent("기록", value: "\(dashboard.summary.todayRecordCount)건")
                    LabeledContent("긴급 호출", value: "\(dashboard.summary.activeEmergencyCount)건")
                    LabeledContent("폭염 단계", value: ["미입력", "주의보", "경보", "중대경보"][max(0, min(3, dashboard.heatLevel))])
                    if let temperature = dashboard.weather?.temperature {
                        LabeledContent("온도", value: "\(temperature.formatted())°C")
                    }
                    if let humidity = dashboard.weather?.humidity {
                        LabeledContent("습도", value: "\(humidity.formatted())%")
                    }
                }
                Section("최근 현장 기록") {
                    if dashboard.recentRecords.isEmpty { Text("등록된 기록이 없어요.") }
                    ForEach(dashboard.recentRecords) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(["THERMOMETER": "온도계", "WORK": "작업사진", "REST": "휴식사진"][record.type] ?? record.type)
                                .font(.headline)
                            Text([record.teamName, record.workplace, record.measuredAt].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else if loading { ProgressView("현장 정보를 불러오는 중...") }
        }
        .navigationTitle(site.siteName)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("현장 전환") { dismiss() } } }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } } else { dashboard = nil }
        }
    }

    @MainActor
    private func load() async {
        guard !loading else { return }
        loading = true
        dashboard = nil
        error = nil
        defer { loading = false }
        do { dashboard = try await service.dashboard(siteID: site.id) } catch { self.error = HGErrorPresentation(error: error) }
    }
}
