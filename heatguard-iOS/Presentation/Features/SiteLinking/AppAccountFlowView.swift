import SwiftUI

struct AppAccountFlowView: View {
    let linkToken: String?
    let onClose: () -> Void

    private let service = HGAppSiteLinkingService()
    @State private var isAuthenticated = false
    @State private var hasClaimedLink = false
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var phoneNumber = ""
    @State private var sites: [HGAppSite] = []
    @State private var selectedSiteID: String?
    @State private var busy = false
    @State private var error: HGErrorPresentation?
    @State private var notice: String?

    var body: some View {
        Group {
            if !isAuthenticated {
                accessForm
            } else if let linkToken, !hasClaimedLink {
                AppSitePhoneEntryView(
                    onSubmit: { phone in
                        Task { await claimLink(token: linkToken, phone: phone) }
                    },
                    onBack: { hasClaimedLink = true }
                )
            } else {
                siteList
            }
        }
        .task { await restore() }
        .alert(
            error?.title ?? "현장 연동",
            isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
        .alert("안내", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    private var accessForm: some View {
        VStack(spacing: 0) {
            flowHeader(title: isRegistering ? "앱 계정 만들기" : "앱 계정 로그인")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(isRegistering ? "이메일로 가입하기" : "앱 계정으로 로그인")
                        .font(HGFont.bold(25, relativeTo: .title2))
                        .foregroundStyle(HGColor.primaryText)
                    Text("현장 연동을 위해 앱 계정이 필요해요.")
                        .font(HGFont.regular(14, relativeTo: .subheadline))
                        .foregroundStyle(HGColor.secondaryText)
                    HGTextField(title: "이메일", placeholder: "example@email.com", text: $email, inputType: .email)
                    if isRegistering {
                        VStack(alignment: .leading, spacing: 8) {
                            Button(busy ? "인증 메일 발송 중..." : "인증 코드 받기") {
                                Task { await requestCode() }
                            }
                            .font(HGFont.semiBold(14))
                            .disabled(busy)
                            HGTextField(title: "이메일 인증 코드", placeholder: "6자리 코드", text: $verificationCode)
                        }
                    }
                    HGTextField(
                        title: "비밀번호",
                        placeholder: "비밀번호를 입력해주세요",
                        text: $password,
                        isSecure: true,
                        inputType: .newPassword
                    )
                    if let error {
                        Text(error.alertMessage)
                            .font(HGFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(HGColor.error)
                    }
                    HGPrimaryButton(title: busy ? "처리 중..." : (isRegistering ? "가입하고 로그인" : "로그인"), isEnabled: !busy) {
                        Task { await submitAccess() }
                    }
                    Button(isRegistering ? "이미 계정이 있어요 · 로그인" : "계정이 없으신가요? · 회원가입") {
                        isRegistering.toggle()
                        error = nil
                    }
                    .font(HGFont.medium(14))
                    .foregroundStyle(HGColor.primary)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
        .background(HGColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var siteList: some View {
        VStack(spacing: 0) {
            flowHeader(title: "내 현장 목록")
            if sites.isEmpty {
                ContentUnavailableView(
                    "연동된 현장이 없어요",
                    systemImage: "building.2",
                    description: Text("관리자가 공유한 연동 링크를 열어 현장을 추가해주세요.")
                )
                Spacer()
            } else {
                List(sites) { site in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(HGColor.checklistSuccess)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.siteName).font(HGFont.semiBold(15))
                            if let managerName = site.managerName {
                                Text("담당자 · \(managerName)")
                                    .font(HGFont.regular(12, relativeTo: .caption))
                                    .foregroundStyle(HGColor.secondaryText)
                            }
                        }
                        Spacer()
                        Button(selectedSiteID == site.id ? "선택됨" : "선택") {
                            Task { await select(site) }
                        }
                        .font(HGFont.medium(12))
                        .foregroundStyle(HGColor.primary)
                        Menu {
                            Button("현장 연동 해제", role: .destructive) {
                                Task { await unlink(site) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(HGColor.secondaryText)
                                .padding(8)
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(HGColor.surface)
                }
                .scrollContentBackground(.hidden)
                .background(HGColor.appBackground)
            }
            Spacer(minLength: 8)
            Button("로그아웃") {
                Task { await logout() }
            }
            .font(HGFont.medium(14))
            .foregroundStyle(HGColor.secondaryText)
            .padding(.bottom, 16)
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .refreshable { await loadSites() }
    }

    private func flowHeader(title: String) -> some View {
        ZStack {
            Text(title)
                .font(HGFont.semiBold(18, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HGColor.primaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .background(HGColor.surface)
    }

    @MainActor
    private func restore() async {
        do {
            isAuthenticated = try await service.restoreSession()
            if isAuthenticated && linkToken == nil { await loadSites() }
        } catch {
            isAuthenticated = false
        }
    }

    @MainActor
    private func requestCode() async {
        busy = true
        defer { busy = false }
        do {
            try await service.requestEmailCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            notice = "인증 코드를 이메일로 보냈어요. 10분 안에 입력해주세요."
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func submitAccess() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if isRegistering {
                try await service.register(email: normalizedEmail, password: password, verificationCode: verificationCode)
            }
            try await service.login(email: normalizedEmail, password: password)
            isAuthenticated = true
            if linkToken == nil { await loadSites() }
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func claimLink(token: String, phone: String) async {
        busy = true
        defer { busy = false }
        do {
            let linkedSite = try await service.claim(token: token, managerPhone: phone)
            sites = try await service.fetchSites()
            selectedSiteID = linkedSite.siteID
            UserDefaults.standard.set(linkedSite.siteID, forKey: "selected-app-site-id")
            hasClaimedLink = true
            notice = "\(linkedSite.siteName) 현장이 연동됐어요."
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func loadSites() async {
        do {
            sites = try await service.fetchSites()
            selectedSiteID = UserDefaults.standard.string(forKey: "selected-app-site-id")
            if let selectedSiteID, !sites.contains(where: { $0.id == selectedSiteID }) {
                self.selectedSiteID = nil
                UserDefaults.standard.removeObject(forKey: "selected-app-site-id")
            }
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func select(_ site: HGAppSite) async {
        do {
            _ = try await service.select(siteID: site.id)
            selectedSiteID = site.id
            UserDefaults.standard.set(site.id, forKey: "selected-app-site-id")
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func unlink(_ site: HGAppSite) async {
        do {
            try await service.unlink(siteID: site.id)
            if selectedSiteID == site.id {
                selectedSiteID = nil
                UserDefaults.standard.removeObject(forKey: "selected-app-site-id")
            }
            await loadSites()
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func logout() async {
        await service.logout()
        isAuthenticated = false
        sites = []
    }
}
