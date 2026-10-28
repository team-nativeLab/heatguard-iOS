//
//  LoginView.swift
//  heatguard-iOS
//

import SwiftUI
import UIKit

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var requestError: HGErrorPresentation?
    @State private var keyboardHeight: CGFloat = 0

    private let authenticationService = HGAuthenticationService()
    private let onAuthenticated: (TeamSession) -> Void
    private let onSignUpTap: () -> Void

    init(
        onAuthenticated: @escaping (TeamSession) -> Void = { _ in },
        onSignUpTap: @escaping () -> Void = {}
    ) {
        self.onAuthenticated = onAuthenticated
        self.onSignUpTap = onSignUpTap
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalInset = min(28, max(18, geometry.size.width * 0.06))
            let fieldInset = min(36, max(28, geometry.size.width * 0.08))

            ZStack(alignment: .top) {
                HGColor.surface
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Image("BrandIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .padding(.top, 54)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("안전한 현장을 위해\n로그인해주세요")
                            .font(HGFont.bold(25, relativeTo: .title))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("팀 계정 이메일과 비밀번호로 로그인할 수 있어요")
                            .font(HGFont.regular(14))
                            .foregroundStyle(HGColor.secondaryText)
                            .padding(.top, 8)
                        VStack(spacing: keyboardHeight > 0 ? 18 : 26) {
                            HGTextField(title: "이메일", placeholder: "example@email.com", text: $email, inputType: .email)
                            HGTextField(
                                title: "비밀번호", placeholder: "비밀번호를 입력해주세요", text: $password, isSecure: true,
                                errorMessage: requestError?.message, inputType: .currentPassword)
                        }
                        .padding(.top, keyboardHeight > 0 ? 14 : 31)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, fieldInset)
                    .padding(.top, 34)

                    Spacer(minLength: keyboardHeight > 0 ? 0 : 32)
                    HGPrimaryButton(
                        title: isSubmitting ? "로그인 중..." : "로그인",
                        isEnabled: !isSubmitting,
                        isLoading: isSubmitting,
                        height: HGLayout.primaryButtonHeight,
                        font: HGFont.bold(15),
                        cornerRadius: 14,
                        tint: HGColor.loginPrimary
                    ) { login() }
                    .padding(.horizontal, horizontalInset)
                    HStack(spacing: 6) {
                        Text("계정이 없으신가요?")
                            .foregroundStyle(HGColor.secondaryText)
                        Button("회원가입", action: onSignUpTap)
                            .font(HGFont.semiBold(13))
                            .foregroundStyle(HGColor.primary)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .padding(.top, keyboardHeight > 0 ? 8 : 14)
                    .padding(.bottom, keyboardHeight > 0 ? 8 : 14)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .offset(y: -HGKeyboardMotion.loginLift(
                    keyboardHeight: keyboardHeight,
                    bottomSafeArea: geometry.safeAreaInsets.bottom
                ))
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background {
            HGColor.surface.ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            withAnimation(HGKeyboardMotion.animation(for: notification)) {
                keyboardHeight = HGKeyboardMotion.overlapHeight(for: notification)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardOnBackgroundTap()
    }

    private func login() {
        UIApplication.shared.dismissKeyboard()
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            requestError = HGErrorPresentation(
                title: "입력 정보를 확인해주세요",
                message: "이메일과 비밀번호를 입력해주세요.",
                diagnosticCode: "INPUT_REQUIRED"
            )
            return
        }

        isSubmitting = true
        requestError = nil

        Task {
            defer { isSubmitting = false }

            do {
                let session = try await authenticationService.login(email: trimmedEmail, password: password)
                onAuthenticated(session)
            } catch {
                requestError = HGErrorPresentation(error: error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
