//
//  LoginView.swift
//  heatguard-iOS
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var requestError: String?

    private let authenticationService = HGAuthenticationService()
    private let onAuthenticated: (SiteSession) -> Void

    init(onAuthenticated: @escaping (SiteSession) -> Void = { _ in }) {
        self.onAuthenticated = onAuthenticated
    }

    var body: some View {
        VStack(spacing: 0) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.top, 87)

            VStack(alignment: .leading, spacing: 0) {
                Text("안전한 현장을 위해\n로그인해주세요")
                    .font(HGFont.bold(25, relativeTo: .title))
                    .foregroundStyle(HGColor.primaryText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("현장작업자 계정으로 로그인할 수 있어요")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.top, 8)

                VStack(spacing: 26) {
                    HGTextField(
                        title: "이메일",
                        placeholder: "example@email.com",
                        text: $email,
                        inputType: .email
                    )

                    HGTextField(
                        title: "비밀번호",
                        placeholder: "비밀번호를 입력해주세요",
                        text: $password,
                        isSecure: true
                    )
                }
                .padding(.top, 31)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 58)

            Spacer(minLength: 24)

            HGPrimaryButton(
                title: isSubmitting ? "로그인 중..." : "로그인",
                isEnabled: !isSubmitting,
                height: 42
            ) {
                login()
            }
                .padding(.horizontal, 40)

            if let requestError {
                Text(requestError)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.error)
                    .padding(.top, 8)
            }

            HStack(spacing: 24) {
                Text("아직 계정이 없으신가요?")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)

                NavigationLink("회원가입") {
                    SignupView()
                }
                    .font(HGFont.bold(14))
                    .foregroundStyle(HGColor.primary)
            }
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .background(HGColor.surface)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func login() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            requestError = "이메일과 비밀번호를 입력해주세요."
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
                requestError = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
