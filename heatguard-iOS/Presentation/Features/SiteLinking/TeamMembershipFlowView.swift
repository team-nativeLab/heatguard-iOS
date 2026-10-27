import SwiftUI

private enum TeamRegistrationStep: Equatable {
    case email
    case verification
    case password
}

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
    @State private var passwordConfirmation = ""
    @State private var verificationCode = ""
    @State private var verificationErrorMessage: String?
    @State private var registrationStep = TeamRegistrationStep.email
    @FocusState private var isVerificationCodeFocused: Bool
    @State private var memberships: [HGTeamMembership] = []
    @State private var selectedTeamID: String?
    @State private var selectingTeamID: String?
    @State private var busy = false
    @State private var error: HGErrorPresentation?

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
            flowHeader(
                title: isRegistering ? "회원가입" : "로그인",
                onBack: handleAccessBack
            )
            ScrollView {
                Group {
                    if isRegistering {
                        registrationContent
                    } else {
                        loginContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isRegistering {
                    registrationFooter
                } else {
                    Color.clear.frame(height: 16).allowsHitTesting(false)
                }
            }
        }
        .dismissKeyboardOnBackgroundTap()
        .background(HGColor.appBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var loginContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("현장 작업자 계정으로 로그인")
                .font(HGFont.bold(25, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
            Text("이메일 계정으로 로그인하고 초대받은 현장에 참여할 수 있어요.")
                .font(HGFont.regular(14, relativeTo: .subheadline))
                .foregroundStyle(HGColor.secondaryText)
            HGTextField(title: "이메일", placeholder: "example@email.com", text: $email, inputType: .email)
            HGTextField(
                title: "비밀번호",
                placeholder: "비밀번호를 입력해주세요",
                text: $password,
                isSecure: true,
                inputType: .currentPassword
            )
            if let error {
                Text(error.alertMessage)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.error)
            }
            HGPrimaryButton(
                title: busy ? "로그인 중..." : "로그인",
                isEnabled: !busy
            ) {
                Task { await submitAccess() }
            }
            Button("계정이 없으신가요? · 회원가입", action: beginRegistration)
                .font(HGFont.medium(14))
                .foregroundStyle(HGColor.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var registrationContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            registrationProgress
            switch registrationStep {
            case .email:
                emailStepContent
            case .verification:
                verificationStepContent
            case .password:
                passwordStepContent
            }
        }
    }

    private var registrationProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { step in
                    Capsule()
                        .fill(step <= registrationStepNumber ? HGColor.primary : HGColor.menuDivider)
                        .frame(height: 4)
                }
            }
            Text("\(registrationStepNumber) / 3 · \(registrationStepTitle)")
                .font(HGFont.medium(11, relativeTo: .caption))
                .foregroundStyle(HGColor.primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var emailStepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("로그인에 사용할\n이메일을 입력해주세요")
                .font(HGFont.bold(22, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("입력한 이메일로 6자리 인증번호를 보내드려요")
                .font(HGFont.regular(13, relativeTo: .subheadline))
                .foregroundStyle(HGColor.secondaryText)
            HGTextField(
                title: "이메일",
                placeholder: "가입할 이메일을 입력해주세요",
                text: $email,
                fieldHeight: 50,
                inputType: .email
            )
            .accessibilityIdentifier("signup.email")
        }
    }

    private var verificationStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("인증번호를\n입력해주세요")
                .font(HGFont.bold(22, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(email.trimmingCharacters(in: .whitespacesAndNewlines))로 보낸 6자리 숫자를 입력해주세요\n메일이 없다면 스팸함을 확인해주세요")
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            verificationCodeInput

        }
    }

    private var verificationCodeInput: some View {
        let digits = Array(verificationCode)
        return HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                Text(index < digits.count ? String(digits[index]) : "")
                    .font(HGFont.semiBold(20, relativeTo: .title3))
                    .foregroundStyle(HGColor.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 11))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(
                                isVerificationCodeFocused && index == min(digits.count, 5) ? HGColor.primary : HGColor.menuDivider,
                                lineWidth: 1
                            )
                    }
            }
        }
        .overlay {
            TextField("", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isVerificationCodeFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .opacity(0.02)
                .accessibilityLabel("이메일 인증번호 6자리")
                .accessibilityIdentifier("signup.verification.code")
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: HGKeyboardInputFramesPreferenceKey.self,
                            value: [geometry.frame(in: .named(HGKeyboardDismissTapConstants.coordinateSpace))]
                        )
                    }
                }
                .onChange(of: verificationCode) { _, value in
                    let digitsOnly = String(value.filter(\.isNumber).prefix(6))
                    if digitsOnly != value { verificationCode = digitsOnly }
                    verificationErrorMessage = nil
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { isVerificationCodeFocused = true }
    }

    private var passwordStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("비밀번호를\n설정해주세요")
                .font(HGFont.bold(22, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("마지막 단계예요. 로그인할 때 사용할 비밀번호를 정해주세요")
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .foregroundStyle(HGColor.primary)
                Text("인증번호 입력됨")
                    .font(HGFont.semiBold(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.primary)
                Text(email.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.primaryText)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(HGColor.photoSelectionBackground, in: RoundedRectangle(cornerRadius: 10))
            HGTextField(
                title: "비밀번호",
                placeholder: "비밀번호를 입력해주세요",
                text: $password,
                isSecure: true,
                fieldHeight: 46,
                inputType: .newPassword
            )
            Text("영문, 숫자를 포함해 8자 이상 입력해 주세요")
                .font(HGFont.regular(11, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
        }
    }

    @ViewBuilder
    private var registrationFooter: some View {
        VStack(spacing: 12) {
            if registrationStep == .email {
                HStack(spacing: 6) {
                    Text("이미 계정이 있으신가요?")
                        .foregroundStyle(HGColor.secondaryText)
                    Button("로그인") { onClose() }
                        .font(HGFont.semiBold(13))
                        .foregroundStyle(HGColor.primary)
                }
                .font(HGFont.regular(12, relativeTo: .caption))
            }

            HGPrimaryButton(
                title: registrationButtonTitle,
                isEnabled: canContinueRegistration && !busy
            ) {
                Task { await continueRegistration() }
            }
            .accessibilityIdentifier("signup.continue")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(HGColor.appBackground)
    }

    private var registrationStepNumber: Int {
        switch registrationStep {
        case .email: 1
        case .verification: 2
        case .password: 3
        }
    }

    private var registrationStepTitle: String {
        switch registrationStep {
        case .email: "이메일 입력"
        case .verification: "이메일 인증"
        case .password: "비밀번호 설정"
        }
    }

    private var registrationButtonTitle: String {
        switch registrationStep {
        case .email: busy ? "인증번호 보내는 중..." : "인증번호 받기"
        case .verification: "다음"
        case .password: busy ? "가입 중..." : "가입 완료"
        }
    }

    private var canContinueRegistration: Bool {
        switch registrationStep {
        case .email: isValidEmail(email)
        case .verification: verificationCode.count == 6
        case .password: isValidPassword
        }
    }

    private var isValidPassword: Bool {
        password.count >= 8
            && password.contains(where: \.isLetter)
            && password.contains(where: \.isNumber)
    }

    private func isValidEmail(_ value: String) -> Bool {
        let normalizedEmail = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedEmail.contains("@") && normalizedEmail.split(separator: "@").last?.contains(".") == true
    }

    private func handleAccessBack() {
        guard isRegistering else {
            onClose()
            return
        }
        switch registrationStep {
        case .email:
            onClose()
        case .verification:
            registrationStep = .email
        case .password:
            registrationStep = .verification
        }
    }

    private func beginRegistration() {
        registrationStep = .email
        verificationCode = ""
        password = ""
        passwordConfirmation = ""
        verificationErrorMessage = nil
        error = nil
        isRegistering = true
    }

    @MainActor
    private func continueRegistration() async {
        guard canContinueRegistration, !busy else { return }
        switch registrationStep {
        case .email:
            await requestCode()
        case .verification:
            // The existing team API validates the code together with account creation.
            registrationStep = .password
            isVerificationCodeFocused = false
        case .password:
            await submitAccess()
        }
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
        topInset: CGFloat = 0,
        onBack: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            Text(title)
                .font(HGFont.semiBold(18, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)
            HStack {
                Button(action: onBack ?? onClose) {
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
        guard isValidEmail(normalizedEmail) else {
            showInputError("올바른 이메일 주소를 입력해주세요.")
            return
        }

        busy = true
        defer { busy = false }
        do {
            try await service.requestRegistrationCode(email: normalizedEmail)
            email = normalizedEmail
            verificationCode = ""
            registrationStep = .verification
            isVerificationCodeFocused = true
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
        if isRegistering {
            guard isValidPassword else {
                showInputError("영문과 숫자를 포함해 8자 이상 입력해주세요.")
                return
            }
            guard normalizedVerificationCode.count == 6 else {
                registrationStep = .verification
                showInputError("이메일 인증번호 6자리를 입력해주세요.")
                return
            }
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
