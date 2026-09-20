//
//  SignupView.swift
//  heatguard-iOS
//

import SwiftUI
import UIKit

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var companyName = ""
    @State private var siteName = ""
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var hasAttemptedSignup = false
    @State private var isSubmitting = false
    @State private var requestError: String?
    @State private var showsSignupSuccess = false

    private let authenticationService = HGAuthenticationService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("현장작업자 회원가입")
                    .font(HGFont.bold(25, relativeTo: .title))
                    .foregroundStyle(HGColor.primaryText)

                Text("현장 정보를 등록하고 안전 관리를 시작해보세요")
                    .font(HGFont.regular(13, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.top, 8)

                VStack(spacing: 21) {
                    signupField(
                        title: "회사명",
                        placeholder: "회사명을 입력해주세요",
                        text: $companyName,
                        errorMessage: companyNameError
                    )

                    signupField(
                        title: "현장명",
                        placeholder: "현장명을 입력해주세요",
                        text: $siteName,
                        errorMessage: siteNameError
                    )

                    signupField(
                        title: "이름",
                        placeholder: "가입자명을 입력해주세요",
                        text: $name,
                        errorMessage: nameError
                    )

                    signupField(
                        title: "이메일",
                        placeholder: "example@email.com",
                        text: $email,
                        inputType: .email,
                        errorMessage: emailError
                    )

                    signupField(
                        title: "비밀번호",
                        placeholder: "8자 이상 입력해주세요",
                        text: $password,
                        isSecure: true,
                        errorMessage: passwordError
                    )

                    signupField(
                        title: "비밀번호",
                        placeholder: "비밀번호를 한 번 더 입력해주세요",
                        text: $passwordConfirmation,
                        isSecure: true,
                        errorMessage: passwordConfirmationError
                    )
                }
                .padding(.top, 35)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.top, 88)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAction
        }
        .background {
            HGColor.surface
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("완료") {
                    dismissKeyboard()
                }
            }
        }
        .alert("회원가입", isPresented: $showsSignupSuccess) {
            Button("로그인하기") {
                dismiss()
            }
        } message: {
            Text("회원가입이 완료됐습니다. 로그인해주세요.")
        }
    }

    private var bottomAction: some View {
        VStack(spacing: 0) {
            HGPrimaryButton(
                title: isSubmitting ? "회원가입 중..." : "회원가입",
                isEnabled: !isSubmitting,
                height: 42
            ) {
                validateSignup()
            }
            .padding(.horizontal, 40)

            if let requestError {
                Text(requestError)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.error)
                    .padding(.top, 8)
            }

            HStack(spacing: 21) {
                Text("이미 계정이 있으신가요?")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)

                Button("로그인") {
                    dismiss()
                }
                .font(HGFont.bold(14))
                .foregroundStyle(HGColor.primary)
            }
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .background(HGColor.surface)
    }

    private func signupField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        inputType: HGTextFieldInputType = .standard,
        isSecure: Bool = false,
        errorMessage: String? = nil
    ) -> some View {
        HGTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            isSecure: isSecure,
            errorMessage: errorMessage,
            fieldHeight: 44,
            cornerRadius: 11,
            textSize: 13,
            titleLeadingPadding: 10,
            inputType: inputType
        )
    }

    private var companyNameError: String? {
        errorMessage(for: companyName, emptyMessage: "회사명을 입력해주세요.")
    }

    private var nameError: String? {
        errorMessage(for: name, emptyMessage: "이름을 입력해주세요.")
    }

    private var siteNameError: String? {
        errorMessage(for: siteName, emptyMessage: "현장명을 입력해주세요.")
    }

    private var emailError: String? {
        guard hasAttemptedSignup else { return nil }
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "이메일을 입력해주세요."
        }
        return isValidEmail ? nil : "올바른 이메일 형식이 아닙니다."
    }

    private var passwordError: String? {
        guard hasAttemptedSignup else { return nil }
        if password.isEmpty {
            return "비밀번호를 입력해주세요."
        }
        return password.count >= 8 ? nil : "비밀번호는 8자 이상 입력해주세요."
    }

    private var passwordConfirmationError: String? {
        guard hasAttemptedSignup else { return nil }
        guard !passwordConfirmation.isEmpty else {
            return "비밀번호를 한 번 더 입력해주세요."
        }
        return password == passwordConfirmation ? nil : "비밀번호가 일치하지 않습니다."
    }

    private var isValidEmail: Bool {
        email.range(
            of: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func errorMessage(for text: String, emptyMessage: String) -> String? {
        guard hasAttemptedSignup else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyMessage : nil
    }

    private func validateSignup() {
        hasAttemptedSignup = true
        dismissKeyboard()

        guard
            companyNameError == nil,
            siteNameError == nil,
            nameError == nil,
            emailError == nil,
            passwordError == nil,
            passwordConfirmationError == nil
        else {
            return
        }

        submitSignup()
    }

    private func submitSignup() {
        isSubmitting = true
        requestError = nil

        let request = SiteRegistrationRequest(
            companyName: companyName.trimmingCharacters(in: .whitespacesAndNewlines),
            managerName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            siteName: siteName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )

        Task {
            defer { isSubmitting = false }

            do {
                try await authenticationService.register(request)
                showsSignupSuccess = true
            } catch {
                requestError = error.localizedDescription
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

#Preview {
    NavigationStack {
        SignupView()
    }
}
