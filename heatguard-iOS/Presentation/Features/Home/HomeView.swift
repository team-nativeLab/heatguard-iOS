import OSLog
import SwiftUI
import UIKit

struct HomeView: View {
    private static let weatherLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HeatGuard",
        category: "WeatherRefresh"
    )

    @Environment(\.scenePhase) private var scenePhase
    let onSessionEnded: () -> Void
    private let onTeamSelectionRequested: () -> Void
    private let loadsRemoteData: Bool

    init(
        initialDashboard: HomeDashboard? = nil,
        initialProfile: HGTeamProfile? = nil,
        onSessionEnded: @escaping () -> Void = {},
        onTeamSelectionRequested: @escaping () -> Void = {}
    ) {
        self.onSessionEnded = onSessionEnded
        self.onTeamSelectionRequested = onTeamSelectionRequested
        self.loadsRemoteData = initialDashboard == nil
        _dashboard = State(initialValue: initialDashboard ?? .unavailable)
        _teamProfile = State(initialValue: initialProfile)
        _checklist = State(initialValue: initialDashboard?.checklist ?? HGChecklistSummary(times: [], checkedCount: nil, totalCount: nil))
        _unreadNotificationCount = State(initialValue: initialDashboard?.unreadNotificationCount ?? 0)
    }

    @State private var resultSheet: RecordResultSheet?
    @State private var showsWithdrawalCompleted = false
    @State private var showsRecordTypes = false
    @State private var showsMenuDrawer = false
    @State private var isMenuDrawerVisible = false
    @State private var emergencySheet: EmergencySheet?
    @State private var isCreatingEmergencyCall = false
    @State private var activeEmergencyCallID: String?
    @State private var activeEmergencyCallStatus: HGEmergencyCallStatus?
    @State private var isUpdatingEmergencyCall = false
    @State private var emergencyStatusError: HGErrorPresentation?
    @State private var hasRequestedTeamSelection = false
    @State private var pendingRecordType: RecordType?
    @State private var flowPath = NavigationPath()
    @State private var dashboard = HomeDashboard.unavailable
    @State private var teamProfile: HGTeamProfile?
    @State private var dashboardError: HGErrorPresentation?
    @State private var unreadNotificationCount = 0
    @State private var emergencyError: HGErrorPresentation?
    @State private var managerPhoneError: HGErrorPresentation?
    @State private var withdrawalError: HGErrorPresentation?
    @State private var isLoggingOut = false
    @State private var checklist = HGChecklistSummary(times: [], checkedCount: nil, totalCount: nil)
    @State private var checklistRounds: HGChecklistRounds?
    @State private var now = Date()
    @State private var storedDraft: HGStoredRecordDraft?
    @State private var failedDraft: HGRecordDraft?
    @State private var failedImages: [UIImage] = []
    @State private var isResumingStoredDraft = false
    @State private var showsStoredDraft = false
    @State private var storedDraftError: String?
    @State private var isRefreshingCurrentLocationWeather = false
    @State private var lastCurrentLocationWeatherAttemptAt: Date?
    @State private var staleLocationWeatherFallback: HGCurrentLocationWeatherCacheEntry?
    @State private var currentLocationWeatherRefreshFailed = false

    var body: some View {
        ZStack {
            NavigationStack(path: $flowPath) {
                homeContent
            }

            if showsMenuDrawer {
                menuDrawerOverlay
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                HGHomeWeatherSummary(
                    weather: displayedWeather,
                    isCompact: false,
                    refreshWarningText: weatherRefreshWarningText
                )
                    .padding(.top, 15)
                sectionLabel("데이터 기록")
                    .padding(.top, 20)
                checkCard(isCompact: false)
                    .padding(.top, 8)
                contactCard(isCompact: false)
                    .padding(.top, 16)
                sectionLabel("추가 기록")
                    .padding(.top, 16)
                VStack(spacing: 8) {
                    HomeActionRow(
                        icon: "HomeCamera",
                        title: "현장 사진",
                        subtitle: "사진 촬영 또는 앨범에서 선택",
                        rowHeight: 69
                    ) {
                        flowPath.append(HomeFlowRoute.fieldPhoto(HGRecordDraft(
                            type: .thermometer,
                            memo: "",
                            temperature: recordWeather.temperature,
                            humidity: recordWeather.humidity,
                            teamName: dashboard.teamName,
                            workplace: dashboard.workplace,
                            siteName: dashboard.siteName
                        )))
                    }
                    .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                    HomeActionRow(
                        icon: "HomeHistory",
                        title: "기록 내역",
                        subtitle: "지금까지의 기록을 확인하세요",
                        rowHeight: 69
                    ) {
                        flowPath.append(HomeFlowRoute.recordHistory)
                    }
                    .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, HGLayout.homeScreenHorizontalPadding)
            .padding(.top, HGLayout.screenTopPadding)
        }
        .scrollIndicators(.hidden)
        .refreshable { await loadDashboard(forceLocationWeatherRefresh: true) }
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HGPrimaryButton(title: "기록하기") {
                showsRecordTypes = true
            }
            .padding(.horizontal, HGLayout.homeScreenHorizontalPadding)
            .padding(.vertical, 10)
            .background(HGColor.appBackground)
        }
        .sheet(item: $resultSheet) { result in
            switch result {
            case .success(let value):
                SaveSuccessView(result: value, onConfirm: returnToHome)
                    .interactiveDismissDisabled()
            case .failure(let value):
                SaveFailureView(failure: value, onRetry: { resultSheet = nil }, onTemporarySave: saveTemporaryAndReturn)
                    .interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: $showsWithdrawalCompleted) {
            WithdrawalCompletedView(onConfirm: finishWithdrawal)
                .interactiveDismissDisabled()
                .presentationDetents([.height(683)])
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $showsRecordTypes, onDismiss: openSelectedRecord) {
            RecordTypeSelectionView { pendingRecordType = $0 }
        }
        .sheet(item: $emergencySheet) { sheet in
            switch sheet {
            case .alert:
                EmergencyAlertView(
                    isCalling: isCreatingEmergencyCall,
                    contact: HGEmergencyContact(name: "본사", phoneNumber: dashboard.companyPhone),
                    error: $emergencyStatusError,
                    onPhoneCall: callCompanyPhone,
                    onCall: beginEmergencyCall
                )
            case .calling:
                EmergencyCallView(
                    isCancelling: isUpdatingEmergencyCall,
                    canCancel: activeEmergencyCallStatus?.canCancel ?? false,
                    contact: HGEmergencyContact(name: "본사", phoneNumber: dashboard.companyPhone),
                    error: $emergencyStatusError,
                    onPhoneCall: callCompanyPhone,
                    onCancel: cancelEmergencyCall
                )
            }
        }
        .navigationDestination(for: HomeFlowRoute.self, destination: destinationView)
        .task {
            guard loadsRemoteData else { return }
            loadStoredDraft()
            async let dashboardLoad: Void = loadDashboard()
            async let emergencyLoad: Void = restoreCurrentEmergencyCall()
            if teamProfile == nil {
                async let profileLoad: Void = loadProfile()
                _ = await (dashboardLoad, profileLoad, emergencyLoad)
            } else {
                _ = await (dashboardLoad, emergencyLoad)
            }
        }
        .task {
            guard loadsRemoteData else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                now = Date()
                await refreshChecklistRounds()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, loadsRemoteData else { return }
            Task {
                now = Date()
                await refreshChecklistRounds()
                await refreshCurrentLocationWeatherIfNeeded()
            }
        }
        .alert("홈 데이터를 불러오지 못했습니다.", isPresented: dashboardErrorAlert) {
            Button("다시 시도") {
                Task { await loadDashboard() }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(dashboardError?.alertMessage ?? "")
        }
        .alert(emergencyError?.title ?? "긴급 호출 상태 확인 오류", isPresented: emergencyErrorAlert) {
            Button("다시 시도") {
                emergencyError = nil
                Task { await restoreCurrentEmergencyCall() }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(emergencyError?.alertMessage ?? "")
        }
        .alert(managerPhoneError?.title ?? "관리자 전화 오류", isPresented: managerPhoneErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(managerPhoneError?.alertMessage ?? "")
        }
        .alert(withdrawalError?.title ?? "회원탈퇴 오류", isPresented: withdrawalErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(withdrawalError?.alertMessage ?? "")
        }
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

    private var displayedWeather: HomeWeather {
        staleLocationWeatherFallback?.weather ?? dashboard.weather
    }

    private var recordWeather: HomeWeather {
        dashboard.weather.isFreshForRecord(asOf: .now) ? dashboard.weather : .unavailable
    }

    private var weatherRefreshWarningText: String? {
        guard currentLocationWeatherRefreshFailed else { return nil }
        return HGHomeWeatherRefreshWarning.text(
            staleAgeDescription: staleLocationWeatherFallback?.ageDescription
        )
    }

    @ViewBuilder
    private var menuDrawerOverlay: some View {
        Color.black.opacity(isMenuDrawerVisible ? 0.4 : 0)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { dismissMenuDrawer() }
            .allowsHitTesting(isMenuDrawerVisible)
            .animation(.easeInOut(duration: 0.24), value: isMenuDrawerVisible)

        HGMenuDrawer(
            profile: teamProfile.map(HGMenuProfile.init(profile:)) ?? .preview,
            isPresented: isMenuDrawerVisible,
            onDismiss: { dismissMenuDrawer() },
            onHome: { dismissMenuDrawer(afterDismiss: returnToHome) },
            onTeamSelection: {
                dismissMenuDrawer(afterDismiss: onTeamSelectionRequested)
            },
            onProfileEdit: {
                dismissMenuDrawer {
                    flowPath.append(HomeFlowRoute.profileEdit)
                }
            },
            onInquiry: {
                dismissMenuDrawer {
                    flowPath.append(HomeFlowRoute.inquiry)
                }
            },
            onLogout: {
                dismissMenuDrawer(afterDismiss: logout)
            },
            onWithdrawal: {
                dismissMenuDrawer {
                    flowPath.append(HomeFlowRoute.withdrawalGuide)
                }
            }
        )
    }

    private var header: some View {
        HGScreenHeader(
            title: "폭염가드",
            onMenuTap: showMenuDrawer,
            notificationCount: unreadNotificationCount,
            onNotificationsTap: showNotifications
        )
    }

    private func showNotifications() {
        flowPath.append(HomeFlowRoute.notifications)
    }

    private func checkCard(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                flowPath.append(HomeFlowRoute.checklistOverview)
            } label: {
                HStack {
                    Text("오늘 체크 시간")
                        .font(HGFont.bold(14, relativeTo: .subheadline))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HGColor.homeChevron)
                }
            }
            .buttonStyle(.plain)

            HomeTimeline(
                rounds: checklistRounds,
                fallbackTimes: checklist.times,
                now: now
            ) { roundID, date in
                flowPath.append(HomeFlowRoute.checklistRound(id: roundID, date: date))
            }
            .padding(.top, isCompact ? 12 : 17)
        }
        .foregroundStyle(HGColor.primaryText)
        .padding(.horizontal, 20)
        .padding(.vertical, isCompact ? 16 : 20)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 120 : 136, alignment: .leading)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityHint("체크리스트 항목을 확인하고 체크합니다")
    }

    private func contactCard(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            HomeActionRow(
                icon: "HomeManagerPhone",
                title: "관리자 전화",
                subtitle: "현장 관리자에게 연락",
                isEnabled: dashboard.managerPhone?.telephoneURL != nil,
                rowHeight: isCompact ? 54 : 65
            ) {
                contactSiteManager()
            }
            Divider().padding(.leading, 16)
            HomeActionRow(
                icon: "HomeEmergencyPhone",
                title: "긴급 호출",
                subtitle: "긴급 호출 등록 및 본사 연락",
                rowHeight: isCompact ? 54 : 65
            ) {
                showEmergencyCall()
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
        guard emergencySheet == .alert, !isCreatingEmergencyCall else { return }
        isCreatingEmergencyCall = true
        Task {
            defer { isCreatingEmergencyCall = false }
            do {
                let service = HGEmergencyCallService()
                let call = try await HGEmergencyCallConfirmation.perform(
                    currentCall: { try await service.fetchCurrentCall() },
                    createCall: { try await service.createCall() }
                )
                activeEmergencyCallID = call.id
                activeEmergencyCallStatus = call.status
                emergencySheet = .calling
            } catch {
                emergencyStatusError = HGErrorPresentation(error: error)
            }
        }
    }

    private func cancelEmergencyCall() {
        guard !isUpdatingEmergencyCall else { return }
        Task {
            isUpdatingEmergencyCall = true
            defer { isUpdatingEmergencyCall = false }

            do {
                let service = HGEmergencyCallService()
                let currentCall = try await service.fetchCurrentCall()

                guard let currentCall, currentCall.status.canCancel else {
                    emergencyStatusError = HGErrorPresentation(
                        title: currentCall?.status == .acknowledged ? "이미 접수된 호출입니다" : "긴급 호출 오류",
                        message: currentCall?.status == .acknowledged
                            ? "접수된 긴급 호출은 취소할 수 없습니다. 현장 관리자에게 연락해주세요."
                            : "취소할 수 있는 진행 중인 호출을 찾지 못했습니다.",
                        diagnosticCode: currentCall?.status == .acknowledged
                            ? "EMERGENCY_CALL_ALREADY_ACKNOWLEDGED"
                            : "EMERGENCY_CALL_NOT_CANCELLABLE"
                    )
                    if let currentCall {
                        activeEmergencyCallID = currentCall.id
                        activeEmergencyCallStatus = currentCall.status
                    }
                    return
                }

                try await service.updateCall(id: currentCall.id, status: .cancelled)
                self.activeEmergencyCallID = nil
                self.activeEmergencyCallStatus = nil
                emergencySheet = nil
            } catch let error as HGAPIError {
                if case let .server(_, statusCode, serverCode) = error,
                   statusCode == 409,
                   serverCode == "INVALID_STATUS_TRANSITION" {
                    if let currentCall = try? await HGEmergencyCallService().fetchCurrentCall() {
                        activeEmergencyCallID = currentCall.id
                        activeEmergencyCallStatus = currentCall.status
                    }
                    emergencyStatusError = HGErrorPresentation(
                        title: "이미 접수된 호출입니다",
                        message: "접수된 긴급 호출은 취소할 수 없습니다. 현장 관리자에게 연락해주세요.",
                        diagnosticCode: "EMERGENCY_CALL_ALREADY_ACKNOWLEDGED"
                    )
                } else {
                    emergencyStatusError = HGErrorPresentation(error: error)
                }
            } catch {
                emergencyStatusError = HGErrorPresentation(error: error)
            }
        }
    }

    private func restoreCurrentEmergencyCall() async {
        do {
            guard let currentCall = try await HGEmergencyCallService().fetchCurrentCall() else { return }
            activeEmergencyCallID = currentCall.id
            activeEmergencyCallStatus = currentCall.status
        } catch {
            guard !Task.isCancelled, !error.hgIsNetworkCancellation else { return }
            if error.requiresTeamSelection {
                requestTeamSelectionIfNeeded()
                return
            }
            emergencyError = HGErrorPresentation(
                title: "긴급 호출 상태를 확인하지 못했습니다",
                message: "네트워크 연결을 확인한 뒤 다시 시도해주세요. 진행 중인 호출은 관리자에게 확인해주세요.",
                diagnosticCode: HGErrorPresentation(error: error).diagnosticCode
            )
        }
    }

    private func showEmergencyCall() {
        emergencyStatusError = nil
        emergencySheet = .alert
    }

    private func contactSiteManager() {
        guard let phoneURL = dashboard.managerPhone?.telephoneURL else {
            managerPhoneError = HGErrorPresentation(
                title: "관리자 연락처 정보가 없습니다",
                message: "현장 관리자 전화번호를 확인한 뒤 다시 시도해주세요.",
                diagnosticCode: "MANAGER_PHONE_UNAVAILABLE"
            )
            return
        }

        UIApplication.shared.open(phoneURL, options: [:]) { didOpen in
            guard !didOpen else { return }
            Task { @MainActor in
                managerPhoneError = HGErrorPresentation(
                    title: "전화 앱을 열지 못했습니다",
                    message: "전화 기능을 사용할 수 있는 기기에서 다시 시도해주세요.",
                    diagnosticCode: "MANAGER_PHONE_OPEN_FAILED"
                )
            }
        }
    }

    private func callCompanyPhone() {
        guard let phoneURL = dashboard.companyPhone?.telephoneURL else { return }
        UIApplication.shared.open(phoneURL, options: [:]) { didOpen in
            guard !didOpen else { return }
            Task { @MainActor in
                emergencyStatusError = HGErrorPresentation(
                    title: "본사 전화 오류",
                    message: "전화 기능을 사용할 수 있는 기기에서 다시 시도해주세요.",
                    diagnosticCode: "COMPANY_PHONE_OPEN_FAILED"
                )
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: HomeFlowRoute) -> some View {
        switch route {
        case .checklistOverview:
            ChecklistOverviewView(
                siteName: dashboard.siteName,
                teamName: dashboard.teamName
            ) { roundID, date in
                flowPath.append(HomeFlowRoute.checklistRound(id: roundID, date: date))
            }
        case let .checklistRound(roundID, date):
            ChecklistRoundDetailView(roundID: roundID, date: date)
        case .thermometer:
            ThermometerRecordView(weather: recordWeather,
                teamName: dashboard.teamName,
                workplace: dashboard.workplace,
                siteName: dashboard.siteName,
                onContinue: { flowPath.append(HomeFlowRoute.fieldPhoto($0)) },
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onNotificationsTap: showNotifications,
                notificationCount: unreadNotificationCount
            )
        case .workPhoto:
            WorkPhotoView(
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onPhotoRequired: showPhotoRequired,
                initialMemo: resumedDraft(for: .work)?.memo ?? "",
                initialPhotos: resumedImages(for: .work),
                initialTemperature: resumedDraft(for: .work)?.temperature,
                initialHumidity: resumedDraft(for: .work)?.humidity,
                weather: recordWeather,
                teamName: dashboard.teamName,
                workplace: dashboard.workplace,
                siteName: dashboard.siteName,
                onNotificationsTap: showNotifications,
                notificationCount: unreadNotificationCount
            )
        case .restPhoto:
            RestPhotoView(
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onPhotoRequired: showPhotoRequired,
                initialMemo: resumedDraft(for: .rest)?.memo ?? "",
                initialPhotos: resumedImages(for: .rest),
                initialTemperature: resumedDraft(for: .rest)?.temperature,
                initialHumidity: resumedDraft(for: .rest)?.humidity,
                weather: recordWeather,
                initialRestStartedAt: resumedDraft(for: .rest)?.restStartedAt,
                initialRestEndedAt: resumedDraft(for: .rest)?.restEndedAt,
                teamName: dashboard.teamName,
                workplace: dashboard.workplace,
                siteName: dashboard.siteName,
                onNotificationsTap: showNotifications,
                notificationCount: unreadNotificationCount
            )
        case let .fieldPhoto(draft):
            FieldPhotoCaptureView(
                draft: draft,
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onPhotoRequired: showPhotoRequired,
                initialPhotos: resumedImages(for: .thermometer),
                onNotificationsTap: showNotifications,
                notificationCount: unreadNotificationCount
            )
        case let .saveBeforeConfirmation(draft):
            SaveBeforeConfirmationView(
                draft: draft,
                onRetry: removeCurrentRoute,
                onSave: showSaveSuccess,
                onFailure: showSaveFailure,
                onNotificationsTap: showNotifications,
                notificationCount: unreadNotificationCount
            )
        case .recordHistory:
            RecordHistoryView { record in
                flowPath.append(HomeFlowRoute.recordDetail(record.recordID))
            } onCreateRecord: {
                showsRecordTypes = true
            }
        case let .recordDetail(recordID):
            RecordDetailView(recordID: recordID)
        case .profileEdit:
            ProfileEditView(profile: teamProfile) { updatedProfile in
                teamProfile = updatedProfile
            }
        case .inquiry:
            InquiryView()
        case let .inquiryDetail(inquiryID):
            InquiryDetailView(inquiryID: inquiryID)
        case let .notificationDetail(notification):
            NotificationDetailView(notification: notification)
        case .notifications:
            NotificationsView { notification in
                switch notification.destination {
                case let .record(id):
                    flowPath.append(HomeFlowRoute.recordDetail(id))
                case let .inquiry(id):
                    flowPath.append(HomeFlowRoute.inquiryDetail(id))
                case .detail:
                    flowPath.append(HomeFlowRoute.notificationDetail(notification))
                }
            } onUnreadCountChanged: { unreadNotificationCount = $0 }
        case .withdrawalGuide:
            WithdrawalGuideView { password, reason in
                Task { await withdraw(password: password, reason: reason) }
            }
        }
    }

    private func removeCurrentRoute() {
        guard !flowPath.isEmpty else { return }
        flowPath.removeLast()
    }

    private func returnToHome() {
        resultSheet = nil
        flowPath = NavigationPath()
        Task { await loadDashboard() }
    }

    private func logout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        Task {
            defer { isLoggingOut = false }
            HGCurrentLocationWeatherCache.shared.clear()
            let authentication = HGAuthenticationService()
            do {
                try await authentication.logout()
            } catch {
                authentication.endLocalSession()
            }
            onSessionEnded()
        }
    }

    private func showMenuDrawer() {
        guard !showsMenuDrawer else { return }
        showsMenuDrawer = true
        DispatchQueue.main.async {
            isMenuDrawerVisible = true
        }
    }

    private func dismissMenuDrawer(afterDismiss: @escaping () -> Void = {}) {
        isMenuDrawerVisible = false
        showsMenuDrawer = false
        afterDismiss()
    }

    private func finishWithdrawal() {
        onSessionEnded()
    }

    @MainActor
    private func withdraw(password: String, reason: String?) async {
        do {
            try await HGAuthenticationService().withdraw(currentPassword: password, reason: reason)
            showsWithdrawalCompleted = true
        } catch {
            withdrawalError = HGErrorPresentation(error: error)
        }
    }

    private func showSaveSuccess(_ result: HGRecordSaveResult) {
        if isResumingStoredDraft {
            try? HGRecordDraftStore().clear()
            clearResumeState()
        }
        resultSheet = .success(result)
    }

    private func showSaveFailure(_ failure: HGRecordSaveFailure, draft: HGRecordDraft, images: [UIImage]) {
        failedDraft = draft
        failedImages = images
        resultSheet = .failure(failure)
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

    private var managerPhoneErrorAlert: Binding<Bool> {
        Binding(get: { managerPhoneError != nil }, set: { if !$0 { managerPhoneError = nil } })
    }

    private var withdrawalErrorAlert: Binding<Bool> {
        Binding(get: { withdrawalError != nil }, set: { if !$0 { withdrawalError = nil } })
    }

    private var storedDraftErrorAlert: Binding<Bool> {
        Binding(get: { storedDraftError != nil }, set: { if !$0 { storedDraftError = nil } })
    }

    @MainActor
    private func loadProfile() async {
        teamProfile = try? await HGAuthenticationService().currentProfile()
    }
}

extension HomeView {
    @MainActor
    fileprivate func refreshCurrentLocationWeatherIfNeeded() async {
        await refreshCurrentLocationWeather(forceRefresh: false)
    }

    @MainActor
    private func refreshCurrentLocationWeather(forceRefresh: Bool) async {
        guard !isRefreshingCurrentLocationWeather else { return }
        let locationProvider = HGCurrentLocationProvider.shared
        let now = Date()
        if !forceRefresh,
           let lastCurrentLocationWeatherAttemptAt,
           now.timeIntervalSince(lastCurrentLocationWeatherAttemptAt) < 60 {
            return
        }

        isRefreshingCurrentLocationWeather = true
        lastCurrentLocationWeatherAttemptAt = now
        defer { isRefreshingCurrentLocationWeather = false }

        do {
            let coordinate = try await locationProvider.currentCoordinate()
            let cachedEntry = HGCurrentLocationWeatherCache.shared.entry(near: coordinate)
            if let cachedEntry, cachedEntry.isFresh(asOf: now) {
                dashboard = dashboard.replacingWeather(cachedEntry.weather)
                staleLocationWeatherFallback = forceRefresh ? cachedEntry : nil
                currentLocationWeatherRefreshFailed = false
                guard forceRefresh else { return }
            } else {
                staleLocationWeatherFallback = cachedEntry
            }

            guard forceRefresh || cachedEntry?.isFresh(asOf: now) != true else { return }
            let weather = try await HGDashboardService().fetchCurrentLocationWeather(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            guard weather.availability != "UNAVAILABLE" else {
                currentLocationWeatherRefreshFailed = true
                return
            }
            dashboard = dashboard.replacingWeather(weather)
            HGCurrentLocationWeatherCache.shared.store(weather, at: coordinate)
            staleLocationWeatherFallback = nil
            currentLocationWeatherRefreshFailed = false
        } catch {
            if error is CancellationError { return }
            Self.weatherLogger.error(
                "Current location weather refresh failed errorType=\(String(describing: type(of: error)), privacy: .public)"
            )
            currentLocationWeatherRefreshFailed = true
        }
    }

    fileprivate func loadDashboard(forceLocationWeatherRefresh: Bool = false) async {
        for attempt in 0 ... 1 {
            do {
                let loadedDashboard = try await HGDashboardService().fetchHomeDashboard()
                hasRequestedTeamSelection = false
                dashboard = loadedDashboard
                unreadNotificationCount = loadedDashboard.unreadNotificationCount
                checklist = loadedDashboard.checklist
                dashboardError = nil
                await refreshCurrentLocationWeather(forceRefresh: forceLocationWeatherRefresh)

                do {
                    let rounds = try await HGChecklistService().fetchRounds()
                    checklistRounds = rounds
                    checklist = HGChecklistSummary(
                        times: loadedDashboard.checklist.times,
                        checkedCount: rounds.items.reduce(0) { $0 + $1.checkedItems },
                        totalCount: rounds.items.reduce(0) { $0 + $1.totalItems }
                    )
                } catch {
                    checklistRounds = nil
                    checklist = loadedDashboard.checklist
                }
                return
            } catch {
                guard !error.hgIsNetworkCancellation else { return }
                if error.requiresTeamSelection {
                    requestTeamSelectionIfNeeded()
                    return
                }
                guard attempt == 0, HGDashboardRetryPolicy.shouldRetry(error) else {
                    dashboardError = HGErrorPresentation(error: error)
                    return
                }

                do {
                    try await Task.sleep(nanoseconds: 350_000_000)
                } catch {
                    return
                }
            }
        }
    }

    @MainActor
    private func refreshChecklistRounds() async {
        do {
            let refreshedRounds = try await HGChecklistService().fetchRounds(date: checklistRounds?.date)
            checklistRounds = refreshedRounds
            checklist = HGChecklistSummary(
                times: checklist.times,
                checkedCount: refreshedRounds.items.reduce(0) { $0 + $1.checkedItems },
                totalCount: refreshedRounds.items.reduce(0) { $0 + $1.totalItems }
            )
        } catch is CancellationError {
            return
        } catch {
            // Keep the last successful timeline until the next refresh succeeds.
        }
    }

    private func requestTeamSelectionIfNeeded() {
        guard !hasRequestedTeamSelection else { return }
        hasRequestedTeamSelection = true
        dashboardError = nil
        emergencyError = nil
        onTeamSelectionRequested()
    }
}

enum HGHomeWeatherRefreshWarning {
    static func text(staleAgeDescription: String?) -> String {
        guard let staleAgeDescription else {
            return "한파특보 정보를 불러오지 못했습니다"
        }
        return "한파특보 정보를 불러오지 못했습니다 · \(staleAgeDescription)"
    }
}

private extension Error {
    var requiresTeamSelection: Bool {
        guard let apiError = self as? HGAPIError,
              case let .server(_, statusCode, serverCode) = apiError else { return false }
        return statusCode == 403 && serverCode == "TEAM_MEMBERSHIP_REQUIRED"
    }
}

private enum HGDashboardRetryPolicy {
    static func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .timedOut,
                .cannotFindHost,
                .cannotConnectToHost,
                .networkConnectionLost,
                .dnsLookupFailed,
                .notConnectedToInternet
            ].contains(urlError.code)
        }

        guard let apiError = error as? HGAPIError,
              case let .server(_, statusCode, _) = apiError else {
            return false
        }
        return statusCode == 408 || statusCode == 429 || (500 ... 599).contains(statusCode)
    }
}

private enum EmergencySheet: Identifiable, Equatable {
    case alert
    case calling

    var id: Self { self }
}

private enum HomeFlowRoute: Hashable {
    case checklistOverview
    case checklistRound(id: String, date: String)
    case thermometer
    case workPhoto
    case restPhoto
    case fieldPhoto(HGRecordDraft)
    case saveBeforeConfirmation(HGRecordDraft)
    case recordHistory
    case recordDetail(String)
    case profileEdit
    case inquiry
    case inquiryDetail(String)
    case notificationDetail(HGNotification)
    case notifications
    case withdrawalGuide

    init(recordType: RecordType) {
        switch recordType {
        case .thermometer: self = .thermometer
        case .workPhoto: self = .workPhoto
        case .restPhoto: self = .restPhoto
        }
    }

}

private struct HomeActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isEnabled = true
    var rowHeight: CGFloat = 65
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
            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .foregroundStyle(HGColor.primaryText)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}

private enum RecordResultSheet: Identifiable {
    case success(HGRecordSaveResult)
    case failure(HGRecordSaveFailure)

    var id: String {
        switch self {
        case .success: "success"
        case .failure: "failure"
        }
    }
}
