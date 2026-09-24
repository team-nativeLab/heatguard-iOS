import SwiftUI
import UIKit

struct HomeView: View {
    @State private var showsRecordTypes = false
    @State private var showsEmergency = false
    @State private var showsCalling = false
    @State private var shouldBeginEmergencyCall = false
    @State private var pendingRecordType: RecordType?
    @State private var flowPath = NavigationPath()
    @State private var dashboard = HomeDashboard.unavailable
    @State private var dashboardError: String?
    @State private var emergencyError: String?
    @State private var checklist = HGChecklistSummary(times: [], checkedCount: 0, totalCount: 0)
    @State private var storedDraft: HGStoredRecordDraft?
    @State private var failedDraft: HGRecordDraft?
    @State private var failedImages: [UIImage] = []
    @State private var isResumingStoredDraft = false
    @State private var showsStoredDraft = false
    @State private var storedDraftError: String?

    var body: some View {
        NavigationStack(path: $flowPath) {
            homeContent
        }
    }

    private var homeContent: some View {
        VStack(spacing: 0) {
            header
            weatherSummary
                .padding(.top, 15)
            sectionLabel("데이터 기록")
                .padding(.top, 20)
            checkCard
                .padding(.top, 8)
            contactCard
                .padding(.top, 16)
            sectionLabel("추가 기록")
                .padding(.top, 16)
            VStack(spacing: 9) {
                HomeActionRow(
                    icon: "HomeCamera",
                    title: "현장 사진",
                    subtitle: "사진 촬영 또는 앨범에서 선택"
                ) {
                    showsRecordTypes = true
                }
                HomeActionRow(
                    icon: "HomeHistory",
                    title: "기록 내역",
                    subtitle: "지금까지의 기록을 확인하세요"
                ) {
                    flowPath.append(HomeFlowRoute.recordHistory)
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 8)
            HGPrimaryButton(title: "기록하기") {
                showsRecordTypes = true
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, HGLayout.homeScreenHorizontalPadding)
        .padding(.top, HGLayout.screenTopPadding)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsRecordTypes, onDismiss: openSelectedRecord) {
            RecordTypeSelectionView { pendingRecordType = $0 }
        }
        .sheet(isPresented: $showsEmergency, onDismiss: beginEmergencyCall) {
            EmergencyAlertView {
                shouldBeginEmergencyCall = true
                showsEmergency = false
            }
        }
        .sheet(isPresented: $showsCalling) {
            EmergencyCallView(onCancel: { showsCalling = false })
        }
        .navigationDestination(for: HomeFlowRoute.self, destination: destinationView)
        .task {
            await loadDashboard()
            await recoverEmergencyCall()
            loadStoredDraft()
        }
        .alert("홈 데이터를 불러오지 못했습니다.", isPresented: dashboardErrorAlert) {
            Button("다시 시도") {
                Task { await loadDashboard() }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(dashboardError ?? "")
        }
        .alert("긴급 호출에 실패했습니다.", isPresented: emergencyErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: { Text(emergencyError ?? "") }
        .alert("임시저장 기록", isPresented: $showsStoredDraft) {
            Button("이어 작성", action: resumeStoredDraft)
            Button("삭제", role: .destructive, action: discardStoredDraft)
            Button("나중에", role: .cancel) {}
        } message: {
            Text("저장하지 않은 기록이 있습니다. 이어서 작성할까요?")
        }
        .alert("임시저장 오류", isPresented: storedDraftErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(storedDraftError ?? "")
        }
    }

    private var header: some View {
        HGScreenHeader()
    }

    private var weatherSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(dashboard.weather.heatLevelTitle)
                        .font(HGFont.bold(10, relativeTo: .caption2))
                        .foregroundStyle(HGColor.homeHeatLevelText)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(HGColor.homeHeatLevelBackground, in: Capsule())

                    Text("현재 온도")
                        .font(HGFont.medium(12, relativeTo: .caption))
                        .padding(.top, 16)

                    HStack(spacing: 8) {
                        Text(dashboard.weather.temperatureText)
                            .font(HGFont.bold(40, relativeTo: .largeTitle))

                        Text("현장 기준")
                            .font(HGFont.bold(9, relativeTo: .caption2))
                            .foregroundStyle(HGColor.error)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background(HGColor.homeBaselineBackground, in: Capsule())
                    }

                    Text("습도 \(dashboard.weather.humidityText) · 체감온도 \(dashboard.weather.apparentTemperatureText)")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .padding(.top, 8)
                }
                Spacer(); Image("WeatherPartlyCloudy").resizable().scaledToFit().frame(width: 145, height: 120).offset(x: 9, y: 2)
            }
            HStack(spacing: 0) {
                HomeMetric(icon: "HomeHumidity", title: "습도", value: dashboard.weather.humidityText)
                Divider().frame(height: 24)
                HomeMetric(icon: "HomeFeelsLike", title: "체감온도", value: dashboard.weather.apparentTemperatureText)
                Divider().frame(height: 24)
                HomeMetric(icon: "HomeWeather", title: "날씨", value: dashboard.weather.weatherStatusText)
            }
            .padding(.horizontal, 18)
            .frame(height: 78)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .foregroundStyle(HGColor.primaryText)
    }

    private var checkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오늘 체크 시간")
                .font(HGFont.bold(14, relativeTo: .subheadline))
            Text(checklist.times.isEmpty ? dashboard.recordStatusText : checklist.statusText)
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
                .padding(.top, 7)
            HomeTimeline(times: checklist.times)
                .padding(.top, 19)
        }
        .foregroundStyle(HGColor.primaryText)
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            HomeActionRow(
                icon: "HomeManagerPhone",
                title: "관리자 전화",
                subtitle: "현장 관리자에게 연락"
            ) {}
            Divider().padding(.leading, 16)
            HomeActionRow(
                icon: "HomeEmergencyPhone",
                title: "긴급 전화",
                subtitle: "본사와 즉시 연결"
            ) {
                showsEmergency = true
            }
        }
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(HGFont.regular(11, relativeTo: .caption2))
            .foregroundStyle(HGColor.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSelectedRecord() {
        guard let pendingRecordType else { return }
        clearResumeState()
        flowPath.append(HomeFlowRoute(recordType: pendingRecordType))
        self.pendingRecordType = nil
    }

    private func beginEmergencyCall() {
        guard shouldBeginEmergencyCall else { return }
        shouldBeginEmergencyCall = false
        Task {
            do {
                _ = try await HGEmergencyCallService().createCall()
                showsCalling = true
            } catch {
                emergencyError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func recoverEmergencyCall() async {
        guard (try? await HGEmergencyCallService().currentCall()) != nil else { return }
        showsCalling = true
    }

    @ViewBuilder
    private func destinationView(for route: HomeFlowRoute) -> some View {
        switch route {
        case .thermometer:
            ThermometerRecordView(
                onContinue: { flowPath.append(HomeFlowRoute.fieldPhoto($0)) }
            )
        case .workPhoto:
            WorkPhotoView(
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onPhotoRequired: showPhotoRequired,
                initialMemo: resumedDraft(for: .work)?.memo ?? "",
                initialPhotos: resumedImages(for: .work)
            )
        case .restPhoto:
            RestPhotoView(
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onPhotoRequired: showPhotoRequired,
                initialMemo: resumedDraft(for: .rest)?.memo ?? "",
                initialPhotos: resumedImages(for: .rest)
            )
        case let .fieldPhoto(draft):
            FieldPhotoCaptureView(
                draft: draft,
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onPhotoRequired: showPhotoRequired,
                initialPhotos: resumedImages(for: .thermometer)
            )
        case let .saveBeforeConfirmation(draft):
            SaveBeforeConfirmationView(
                draft: draft,
                onRetry: removeCurrentRoute,
                onSave: showSaveSuccess,
                onFailure: showSaveFailure
            )
        case let .saveSuccess(result):
            SaveSuccessView(result: result, onConfirm: returnToHome)
        case let .saveFailure(errorMessage):
            SaveFailureView(
                errorMessage: errorMessage,
                onRetry: removeCurrentRoute,
                onTemporarySave: saveTemporaryAndReturn
            )
        case .recordHistory:
            RecordHistoryView { record in
                flowPath.append(HomeFlowRoute.recordDetail(record.recordID))
            }
        case let .recordDetail(recordID):
            RecordDetailView(recordID: recordID)
        }
    }

    private func removeCurrentRoute() {
        guard !flowPath.isEmpty else { return }
        flowPath.removeLast()
    }

    private func returnToHome() {
        flowPath = NavigationPath()
    }

    private func showSaveSuccess(_ result: HGRecordSaveResult) {
        if isResumingStoredDraft {
            try? HGRecordDraftStore().clear()
            clearResumeState()
        }
        flowPath.append(HomeFlowRoute.saveSuccess(result))
    }

    private func showSaveFailure(_ errorMessage: String, draft: HGRecordDraft, images: [UIImage]) {
        failedDraft = draft
        failedImages = images
        flowPath.append(HomeFlowRoute.saveFailure(errorMessage))
    }

    private func showPhotoRequired(_ draft: HGRecordDraft) {
        flowPath.append(HomeFlowRoute.saveBeforeConfirmation(draft))
    }

    private func loadStoredDraft() {
        do {
            storedDraft = try HGRecordDraftStore().load()
            showsStoredDraft = storedDraft != nil
        } catch {
            storedDraftError = error.localizedDescription
        }
    }

    private func resumeStoredDraft() {
        guard let storedDraft else { return }

        isResumingStoredDraft = true
        showsStoredDraft = false

        switch storedDraft.draft.type {
        case .thermometer:
            flowPath.append(HomeFlowRoute.fieldPhoto(storedDraft.draft))
        case .work:
            flowPath.append(HomeFlowRoute.workPhoto)
        case .rest:
            flowPath.append(HomeFlowRoute.restPhoto)
        }
    }

    private func discardStoredDraft() {
        do {
            try HGRecordDraftStore().clear()
            clearResumeState()
        } catch {
            storedDraftError = error.localizedDescription
        }
    }

    private func saveTemporaryAndReturn() {
        guard let failedDraft else { return }

        do {
            try HGRecordDraftStore().save(draft: failedDraft, images: failedImages)
            storedDraft = HGStoredRecordDraft(draft: failedDraft, images: failedImages)
            clearResumeState()
            returnToHome()
        } catch {
            storedDraftError = error.localizedDescription
        }
    }

    private func resumedDraft(for type: HGRecordType) -> HGRecordDraft? {
        guard isResumingStoredDraft, storedDraft?.draft.type == type else { return nil }
        return storedDraft?.draft
    }

    private func resumedImages(for type: HGRecordType) -> [UIImage] {
        guard isResumingStoredDraft, storedDraft?.draft.type == type else { return [] }
        return storedDraft?.images ?? []
    }

    private func clearResumeState() {
        isResumingStoredDraft = false
        storedDraft = nil
    }

    private var dashboardErrorAlert: Binding<Bool> {
        Binding(
            get: { dashboardError != nil },
            set: { if !$0 { dashboardError = nil } }
        )
    }

    private var emergencyErrorAlert: Binding<Bool> {
        Binding(get: { emergencyError != nil }, set: { if !$0 { emergencyError = nil } })
    }

    private var storedDraftErrorAlert: Binding<Bool> {
        Binding(get: { storedDraftError != nil }, set: { if !$0 { storedDraftError = nil } })
    }

    private func loadDashboard() async {
        do {
            let loadedDashboard = try await HGDashboardService().fetchHomeDashboard()
            dashboard = loadedDashboard
            checklist = loadedDashboard.checklist
            dashboardError = nil
        } catch {
            dashboardError = error.localizedDescription
        }
    }
}

private enum HomeFlowRoute: Hashable {
    case thermometer
    case workPhoto
    case restPhoto
    case fieldPhoto(HGRecordDraft)
    case saveBeforeConfirmation(HGRecordDraft)
    case saveSuccess(HGRecordSaveResult)
    case saveFailure(String)
    case recordHistory
    case recordDetail(String)

    init(recordType: RecordType) {
        switch recordType {
        case .thermometer: self = .thermometer
        case .workPhoto: self = .workPhoto
        case .restPhoto: self = .restPhoto
        }
    }

}

private struct HomeMetric: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .frame(width: 36, height: 36)
                .background(
                    HGColor.homeMetricIconBackground,
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HGFont.regular(10, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)

                Text(value)
                    .font(HGFont.bold(14, relativeTo: .caption))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 44, height: 44)
                    .background(
                        HGColor.homeActionIconBackground,
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(HGFont.bold(14, relativeTo: .subheadline))

                    Text(subtitle)
                        .font(HGFont.regular(11, relativeTo: .caption2))
                        .foregroundStyle(HGColor.secondaryText)
                }

                Spacer()

                Text("›")
                    .font(.title3)
                    .foregroundStyle(HGColor.homeChevron)
            }
            .padding(.horizontal, 16)
            .frame(height: 65)
        }
        .buttonStyle(.plain)
        .foregroundStyle(HGColor.primaryText)
    }
}

private struct HomeTimeline: View {
    let times: [String]

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { _ in
                ZStack {
                    Capsule()
                        .fill(HGColor.homeTimelineLine)
                        .frame(height: 2)

                    HStack {
                        ForEach(times.indices, id: \.self) { index in
                            timelinePoint()

                            if index != times.indices.last {
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(height: 12)

            HStack {
                ForEach(times, id: \.self) { time in
                    Text(time)
                        .font(HGFont.regular(9, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)

                    if time != times.last {
                        Spacer()
                    }
                }
            }
        }
    }

    private func timelinePoint() -> some View {
        return Circle()
            .fill(HGColor.surface)
            .overlay {
                Circle()
                    .stroke(
                        HGColor.homeTimelineBorder,
                        lineWidth: 1
                    )
            }
            .frame(width: 8, height: 8)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
