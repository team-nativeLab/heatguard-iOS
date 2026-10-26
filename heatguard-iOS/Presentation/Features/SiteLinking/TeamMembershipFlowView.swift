import SwiftUI

struct TeamMembershipFlowView: View {
    let linkToken: String?
    let onClose: () -> Void
    let onAuthenticated: (TeamSession) -> Void
    let onTeamSelected: () -> Void

    private let service = HGAuthenticationService()
    @State private var isRestoringSession = true
    @State private var isAuthenticated = false
    @State private var hasAcceptedInvitation = false
    @State private var isRegistering: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var memberships: [HGTeamMembership] = []
    @State private var selectedTeamID: String?
    @State private var selectingTeamID: String?
    @State private var busy = false
    @State private var error: HGErrorPresentation?
    @State private var notice: String?

    init(
        linkToken: String? = nil,
        startsWithRegistration: Bool = false,
        onClose: @escaping () -> Void,
        onAuthenticated: @escaping (TeamSession) -> Void = { _ in },
        onTeamSelected: @escaping () -> Void = {}
    ) {
        self.linkToken = linkToken
        self.onClose = onClose
        self.onAuthenticated = onAuthenticated
        self.onTeamSelected = onTeamSelected
        _isRegistering = State(initialValue: startsWithRegistration)
    }

    var body: some View {
        Group {
            if isRestoringSession {
                ProgressView().tint(HGColor.primary)
            } else if !isAuthenticated {
                accessForm
            } else if hasPendingInvitation, !hasAcceptedInvitation {
                invitationConfirmation
            } else {
                membershipList
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
        .onChange(of: linkToken) { _, newToken in
            hasAcceptedInvitation = false
            if newToken?.isEmpty != false, isAuthenticated { Task { await loadMemberships() } }
        }
    }

    private var hasPendingInvitation: Bool {
        linkToken?.isEmpty == false
    }

    private var invitationConfirmation: some View {
        VStack(spacing: 0) {
            flowHeader(title: "현장 연동", backgroundColor: HGColor.appBackground, height: 54, topInset: 10)

            Spacer(minLength: 24)

            VStack(spacing: 16) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(HGColor.primary)
                    .accessibilityHidden(true)
                Text("초대받은 현장에 참여할까요?")
                    .font(HGFont.bold(22, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)
                    .multilineTextAlignment(.center)
                Text("참여하기를 누르면 이 계정으로 현장 연동을 진행합니다.")
                    .font(HGFont.regular(15, relativeTo: .body))
                    .foregroundStyle(HGColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                HGPrimaryButton(
                    title: busy ? "처리 중..." : "현장 참여하기",
                    isEnabled: !busy
                ) {
                    Task { await acceptInvitationIfNeeded() }
                }
                Button("취소", action: onClose)
                    .font(HGFont.semiBold(16, relativeTo: .headline))
                    .foregroundStyle(HGColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(busy)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .overlay {
            if busy { ProgressView().tint(HGColor.primary) }
        }
    }

    private var accessForm: some View {
        VStack(spacing: 0) {
            flowHeader(title: isRegistering ? "회원가입" : "로그인")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(isRegistering ? "현장 작업자 계정 만들기" : "현장 작업자 계정으로 로그인")
                        .font(HGFont.bold(25, relativeTo: .title2))
                        .foregroundStyle(HGColor.primaryText)
                    Text("이메일 계정으로 로그인하고 초대받은 현장에 참여할 수 있어요.")
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
                            HGTextField(
                                title: "이메일 인증 코드",
                                placeholder: "인증 코드",
                                text: $verificationCode,
                                inputType: .number
                            )
                        }
                    }
                    HGTextField(
                        title: "비밀번호",
                        placeholder: "비밀번호를 입력해주세요",
                        text: $password,
                        isSecure: true,
                        inputType: isRegistering ? .newPassword : .currentPassword
                    )
                    if let error {
                        Text(error.alertMessage)
                            .font(HGFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(HGColor.error)
                    }
                    HGPrimaryButton(
                        title: busy ? "처리 중..." : (isRegistering ? "회원가입" : "로그인"),
                        isEnabled: !busy
                    ) {
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
            .scrollDismissesKeyboard(.interactively)
        }
        .dismissKeyboardOnBackgroundTap()
        .background(HGColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var membershipList: some View {
        VStack(spacing: 0) {
            flowHeader(title: "내 현장 목록", backgroundColor: HGColor.appBackground, height: 54, topInset: 10)
            if memberships.isEmpty {
                ContentUnavailableView(
                    "초대받은 현장이 없어요",
                    systemImage: "building.2",
                    description: Text("현장 관리자가 보낸 초대 링크를 열어 현장에 참여해주세요.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(memberships) { membership in
                            membershipCard(membership)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .refreshable { await loadMemberships() }
            }
        }
        .background(HGColor.appBackground.ignoresSafeArea())
        .overlay {
            if busy { ProgressView().tint(HGColor.primary) }
        }
    }

    private func membershipCard(_ membership: HGTeamMembership) -> some View {
        let isSelected = selectedTeamID == membership.teamID
        return Button {
            Task { await select(membership) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if isSelected {
                        Circle().fill(HGColor.primary)
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 32, height: 32)
                Text(membership.displayName)
                    .font(HGFont.semiBold(16, relativeTo: .headline))
                    .foregroundStyle(isSelected ? HGColor.primaryText : HGColor.photoSelectionText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(isSelected ? "선택됨" : "선택 안됨")
                    .font(HGFont.semiBold(13, relativeTo: .subheadline))
                    .foregroundStyle(isSelected ? HGColor.primary : HGColor.photoSelectionText)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(
                isSelected ? HGColor.photoSelectionBackground : HGColor.readOnlyField,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? HGColor.primary : HGColor.homeTimelineBorder, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(selectingTeamID != nil)
        .contextMenu {
            Button("현장 참여 해제", role: .destructive) {
                Task { await leave(membership) }
            }
        }
        .accessibilityLabel("\(membership.displayName), \(isSelected ? "선택됨" : "선택 안됨")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func flowHeader(
        title: String,
        backgroundColor: Color = HGColor.surface,
        height: CGFloat = 48,
        topInset: CGFloat = 0
    ) -> some View {
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
        .frame(height: height)
        .padding(.horizontal, 14)
        .padding(.top, topInset)
        .background(backgroundColor)
    }

    @MainActor
    private func restore() async {
        defer { isRestoringSession = false }
        do {
            isAuthenticated = try await service.restoreSession() != nil
            if isAuthenticated {
                if !hasPendingInvitation { await loadMemberships() }
            }
        } catch {
            isAuthenticated = false
        }
    }

    @MainActor
    private func requestCode() async {
        error = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            showInputError("이메일을 입력해주세요.")
            return
        }

        busy = true
        defer { busy = false }
        do {
            try await service.requestRegistrationCode(email: normalizedEmail)
            notice = "인증 코드를 이메일로 보냈어요."
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func submitAccess() async {
        error = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedVerificationCode = verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            showInputError("이메일을 입력해주세요.")
            return
        }
        guard !password.isEmpty else {
            showInputError("비밀번호를 입력해주세요.")
            return
        }
        if isRegistering && normalizedVerificationCode.isEmpty {
            showInputError("이메일 인증 코드를 입력해주세요.")
            return
        }

        busy = true
        defer { busy = false }
        do {
            if isRegistering {
                try await service.register(
                    email: normalizedEmail,
                    password: password,
                    verificationCode: normalizedVerificationCode
                )
            }
            let session = try await service.login(email: normalizedEmail, password: password)
            isAuthenticated = true
            onAuthenticated(session)
            if hasPendingInvitation {
                return
            } else {
                await loadMemberships()
            }
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func showInputError(_ message: String) {
        error = HGErrorPresentation(
            title: "입력 정보를 확인해주세요",
            message: message,
            diagnosticCode: "INPUT_REQUIRED"
        )
    }

    @MainActor
    private func acceptInvitationIfNeeded() async {
        guard let linkToken, !linkToken.isEmpty, !hasAcceptedInvitation else { return }
        busy = true
        defer { busy = false }
        do {
            try await service.acceptInvitation(token: linkToken)
            hasAcceptedInvitation = true
            await loadMemberships()
            if let selectedTeamID {
                if memberships.contains(where: { $0.teamID == selectedTeamID }) {
                    onTeamSelected()
                }
            }
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func loadMemberships() async {
        do {
            let result = try await service.memberships()
            memberships = result.items
            selectedTeamID = result.selectedTeamID
            if let selectedTeamID, !memberships.contains(where: { $0.teamID == selectedTeamID }) {
                self.selectedTeamID = nil
            }
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func select(_ membership: HGTeamMembership) async {
        guard selectingTeamID == nil, selectedTeamID != membership.teamID else {
            if selectedTeamID == membership.teamID { onTeamSelected() }
            return
        }
        selectingTeamID = membership.teamID
        defer { selectingTeamID = nil }
        do {
            try await service.selectMembership(teamID: membership.teamID)
            selectedTeamID = membership.teamID
            onTeamSelected()
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func leave(_ membership: HGTeamMembership) async {
        do {
            try await service.leaveMembership(teamID: membership.teamID)
            if selectedTeamID == membership.teamID { selectedTeamID = nil }
            await loadMemberships()
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }
}
