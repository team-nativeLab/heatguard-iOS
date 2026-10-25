import SwiftUI

struct AppSiteDashboardView: View {
    let site: HGAppSite
    let onChangeSite: () -> Void
    let onLogout: () -> Void

    @State private var dashboard: HGAppSiteDashboard?
    @State private var isLoading = false
    @State private var error: HGErrorPresentation?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(site.siteName)
                        .font(HGFont.bold(24, relativeTo: .title2))
                        .foregroundStyle(HGColor.primaryText)
                        .padding(.top, 24)

                    weatherCard
                    summaryCards
                    recentRecords

                    if let error {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(error.alertMessage)
                                .font(HGFont.regular(14))
                                .foregroundStyle(HGColor.secondaryText)
                            Button("다시 불러오기") { Task { await loadDashboard() } }
                                .font(HGFont.semiBold(14))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable { await loadDashboard() }
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .task(id: site.id) { await loadDashboard() }
    }

    private var header: some View {
        HStack {
            Text("현장가드")
                .font(HGFont.bold(20, relativeTo: .title3))
                .foregroundStyle(HGColor.primaryText)
            Spacer()
            Button("현장 변경", action: onChangeSite)
                .font(HGFont.semiBold(14))
            Button("로그아웃", action: onLogout)
                .font(HGFont.medium(14))
                .foregroundStyle(HGColor.secondaryText)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(HGColor.surface)
    }

    @ViewBuilder
    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("현장 날씨")
                .font(HGFont.semiBold(16, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)
            if let weather = dashboard?.weather {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(temperatureText(weather.temperature))
                        .font(HGFont.bold(34, relativeTo: .largeTitle))
                    Text("습도 \(weather.humidity.map { "\(Int($0))%" } ?? "—")")
                        .font(HGFont.medium(15))
                        .foregroundStyle(HGColor.secondaryText)
                }
                Text("체감온도 \(temperatureText(weather.apparentTemperature))")
                    .font(HGFont.medium(14))
                    .foregroundStyle(HGColor.secondaryText)
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("날씨 정보가 없어요")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "오늘 기록", value: dashboard?.summary?.todayRecordCount)
            summaryCard(title: "긴급 호출", value: dashboard?.summary?.activeEmergencyCount)
        }
    }

    private func summaryCard(title: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(HGFont.medium(14))
                .foregroundStyle(HGColor.secondaryText)
            if isLoading && value == nil {
                ProgressView()
            } else {
                Text(value.map(String.init) ?? "—")
                    .font(HGFont.bold(27, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(18)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 현장 기록")
                .font(HGFont.semiBold(16, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)
            if let records = dashboard?.recentRecords, !records.isEmpty {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recordTitle(record.type))
                            .font(HGFont.semiBold(14))
                            .foregroundStyle(HGColor.primaryText)
                        HStack {
                            Text(record.teamName ?? "현장 기록")
                            Spacer()
                            Text(record.measuredAt ?? "")
                        }
                        .font(HGFont.regular(12))
                        .foregroundStyle(HGColor.secondaryText)
                    }
                    .padding(.vertical, 10)
                    if record.id != records.last?.id { Divider() }
                }
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 48)
            } else {
                Text("등록된 기록이 없어요")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.vertical, 12)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func loadDashboard() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            dashboard = try await HGAppSiteLinkingService().fetchDashboard(siteID: site.id)
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    private func temperatureText(_ value: Double?) -> String {
        value.map { String(format: "%.1f°C", $0) } ?? "—"
    }

    private func recordTitle(_ type: String?) -> String {
        switch type {
        case "THERMOMETER": "온도계 기록"
        case "WORK": "작업 사진"
        case "REST": "휴식 사진"
        default: "현장 기록"
        }
    }
}
