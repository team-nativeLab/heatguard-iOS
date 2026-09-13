//
//  SignupView.swift
//  heatguard-iOS
//

import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var companyName = ""
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""

    var body: some View {
        VStack(spacing: 0) {
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
                        text: $companyName
                    )

                    signupField(
                        title: "이름",
                        placeholder: "가입자명을 입력해주세요",
                        text: $name
                    )

                    signupField(
                        title: "이메일",
                        placeholder: "example@email.com",
                        text: $email
                    )

                    signupField(
                        title: "비밀번호",
                        placeholder: "8자 이상 입력해주세요",
                        text: $password,
                        isSecure: true
                    )

                    signupField(
                        title: "비밀번호",
                        placeholder: "비밀번호를 한 번 더 입력해주세요",
                        text: $passwordConfirmation,
                        isSecure: true
                    )
                }
                .padding(.top, 35)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.top, 88)

            Spacer(minLength: 24)

            HGPrimaryButton(title: "회원가입", height: 42) {}
                .padding(.horizontal, 40)

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
        .toolbar(.hidden, for: .navigationBar)
    }

    private func signupField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false
    ) -> some View {
        HGTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            isSecure: isSecure,
            fieldHeight: 44,
            cornerRadius: 11,
            textSize: 13,
            titleLeadingPadding: 10
        )
    }
}

#Preview {
    NavigationStack {
        SignupView()
    }
}
