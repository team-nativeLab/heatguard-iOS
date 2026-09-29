import SwiftUI

struct ProfileEditView: View {
    let profile: HGTeamProfile?
    let onProfileUpdated: (HGTeamProfile) -> Void
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var isSaving = false
    @State private var error: HGErrorPresentation?
    @State private var isComplete = false
    @State private var isPasswordChangeComplete = false

    init(profile: HGTeamProfile? = nil, onProfileUpdated: @escaping (HGTeamProfile) -> Void = { _ in }) {
        self.profile = profile
        self.onProfileUpdated = onProfileUpdated
        _name = State(initialValue: profile?.name ?? "")
        _email = State(initialValue: profile?.email ?? "")
        _phone = State(initialValue: profile?.phone ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(name.prefix(1)).font(HGFont.bold(26, relativeTo: .title))
                        .foregroundStyle(HGColor.primary).frame(width: 72, height: 72)
                        .background(HGColor.homeMetricIconBackground, in: Circle())
                    Text("현장작업자").font(HGFont.regular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
                }
                VStack(spacing: 20) {
                    readOnlyField(
                        title: "회사명",
                        value: profile?.companyName ?? "등록된 회사가 없습니다"
                    )
                    HGTextField(title: "이름", placeholder: "이름을 입력해주세요", text: $name, fieldHeight: 48)
                    readOnlyField(
                        title: "이메일",
                        value: email,
                        hint: "로그인에 쓰는 이메일은 변경할 수 없어요"
                    )
                    NavigationLink {
                        PasswordChangeView {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPasswordChangeComplete = true
                            }
                        }
                    } label: {
                        HStack { VStack(alignment: .leading, spacing: 3) { Text("비밀번호 변경").font(HGFont.semiBold(14, relativeTo: .subheadline)); Text("현재 비밀번호 확인 후 변경할 수 있어요").font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(HGColor.homeChevron) }
                            .padding(16).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).foregroundStyle(HGColor.primaryText)
                }
            }.padding(24)
        }
        .background(HGColor.appBackground).navigationTitle("내 정보 수정").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HGPrimaryButton(title: isSaving ? "저장 중..." : "저장하기", isEnabled: isValid && !isSaving) {
                Task { await saveProfile() }
            }
            .padding(.horizontal, 28).padding(.vertical, 10).background(HGColor.appBackground)
        }
        .alert(error?.title ?? "내 정보 수정 오류", isPresented: errorAlert) { Button("확인", role: .cancel) {} } message: { Text(error?.alertMessage ?? "") }
        .alert("내 정보가 수정되었습니다.", isPresented: $isComplete) { Button("확인", role: .cancel) {} }
        .overlay(alignment: .bottom) {
            if isPasswordChangeComplete {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("비밀번호가 변경되었습니다.")
                }
                .font(HGFont.medium(14, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(HGColor.primaryText.opacity(0.92), in: Capsule())
                .padding(.bottom, 86)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPasswordChangeComplete = false
                    }
                }
            }
        }
        .dismissKeyboardOnBackgroundTap()
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@")
    }

    private func readOnlyField(title: String, value: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)
            HStack {
                Text(value.isEmpty ? "정보 없음" : value)
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(value.isEmpty ? HGColor.secondaryText : HGColor.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if title == "이메일" {
                    Text("변경 불가")
                        .font(HGFont.regular(11, relativeTo: .caption2))
                        .foregroundStyle(HGColor.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12))
            if let hint {
                Text(hint)
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    @MainActor
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let updatedProfile = try await HGAuthenticationService().updateProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                version: profile?.version
            )
            name = updatedProfile.name
            email = updatedProfile.email
            phone = updatedProfile.phone ?? ""
            onProfileUpdated(updatedProfile)
            isComplete = true
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }
}

private struct PasswordChangeView: View {
    @Environment(\.dismiss) private var dismiss

    let onComplete: () -> Void
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var isSubmitting = false
    @State private var error: HGErrorPresentation?
    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("현재 비밀번호를 확인한 뒤\n새 비밀번호로 변경할 수 있어요")
                    .font(HGFont.regular(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
                    .lineSpacing(3)

                HGTextField(
                    title: "현재 비밀번호",
                    placeholder: "현재 비밀번호 입력",
                    text: $currentPassword,
                    isSecure: true,
                    fieldHeight: 48,
                    inputType: .currentPassword
                )
                .padding(.top, 20)

                HGTextField(
                    title: "새 비밀번호",
                    placeholder: "새 비밀번호 입력",
                    text: $newPassword,
                    isSecure: true,
                    fieldHeight: 48,
                    inputType: .newPassword
                )
                .padding(.top, 20)

                passwordRuleFeedback
                    .padding(.top, 8)

                HGTextField(
                    title: "새 비밀번호 확인",
                    placeholder: "새 비밀번호 다시 입력",
                    text: $confirmation,
                    isSecure: true,
                    errorMessage: confirmationError,
                    fieldHeight: 48,
                    inputType: .newPassword
                )
                .padding(.top, 20)

                if passwordsMatch {
                    Text("✓ 새 비밀번호가 일치해요")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.primary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HGColor.appBackground)
        .navigationTitle("비밀번호 변경")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await changePassword() }
            } label: {
                Text(isSubmitting ? "변경 중..." : "변경하기")
                    .font(HGFont.semiBold(16, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        HGColor.primary.opacity(isValid && !isSubmitting ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .disabled(!isValid || isSubmitting)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(HGColor.appBackground)
        }
        .dismissKeyboardOnBackgroundTap()
        .alert(error?.title ?? "비밀번호 변경 오류", isPresented: errorAlert) { Button("확인", role: .cancel) {} } message: { Text(error?.alertMessage ?? "") }
    }

    private var meetsPasswordRule: Bool {
        newPassword.count >= 8
            && newPassword.range(of: "[A-Za-z]", options: .regularExpression) != nil
            && newPassword.range(of: "[0-9]", options: .regularExpression) != nil
    }

    private var passwordsMatch: Bool { !confirmation.isEmpty && confirmation == newPassword }

    private var confirmationError: String? {
        guard !confirmation.isEmpty, !passwordsMatch else { return nil }
        return "새 비밀번호가 일치하지 않아요"
    }

    private var passwordRuleFeedback: some View {
        Group {
            if meetsPasswordRule {
                Text("✓ 영문, 숫자를 포함해 8자 이상")
                    .foregroundStyle(HGColor.primary)
            } else {
                Text("영문, 숫자를 포함해 8자 이상 입력해 주세요")
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
        .font(HGFont.regular(12, relativeTo: .caption))
    }

    private var isValid: Bool { !currentPassword.isEmpty && meetsPasswordRule && passwordsMatch }
    private var errorAlert: Binding<Bool> { Binding(get: { error != nil }, set: { if !$0 { error = nil } }) }
    @MainActor private func changePassword() async {
        isSubmitting = true; defer { isSubmitting = false }
        do {
            try await HGAuthenticationService().changePassword(currentPassword: currentPassword, newPassword: newPassword)
            currentPassword = ""
            newPassword = ""
            confirmation = ""
            onComplete()
            dismiss()
        }
        catch { self.error = HGErrorPresentation(error: error) }
    }
}
