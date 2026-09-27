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
                    HGTextField(title: "이름", placeholder: "이름을 입력해주세요", text: $name, fieldHeight: 48)
                    HGTextField(title: "이메일", placeholder: "example@email.com", text: $email, fieldHeight: 48, inputType: .email)
                    HGTextField(title: "전화번호", placeholder: "전화번호를 입력해주세요", text: $phone, fieldHeight: 48)
                    NavigationLink { PasswordChangeView() } label: {
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
        .dismissKeyboardOnBackgroundTap()
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@")
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
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var isSubmitting = false
    @State private var error: HGErrorPresentation?
    @State private var isComplete = false
    var body: some View {
        VStack(spacing: 20) {
            HGTextField(title: "현재 비밀번호", placeholder: "현재 비밀번호를 입력해주세요", text: $currentPassword, isSecure: true, fieldHeight: 48)
            HGTextField(title: "새 비밀번호", placeholder: "새 비밀번호를 입력해주세요", text: $newPassword, isSecure: true, fieldHeight: 48)
            HGTextField(title: "새 비밀번호 확인", placeholder: "새 비밀번호를 다시 입력해주세요", text: $confirmation, isSecure: true, fieldHeight: 48)
            Spacer()
            HGPrimaryButton(title: isSubmitting ? "변경 중..." : "비밀번호 변경", isEnabled: isValid && !isSubmitting) {
                Task { await changePassword() }
            }
        }.padding(24).background(HGColor.appBackground).navigationTitle("비밀번호 변경").navigationBarTitleDisplayMode(.inline).dismissKeyboardOnBackgroundTap()
        .alert(error?.title ?? "비밀번호 변경 오류", isPresented: errorAlert) { Button("확인", role: .cancel) {} } message: { Text(error?.alertMessage ?? "") }
        .alert("비밀번호가 변경되었습니다.", isPresented: $isComplete) { Button("확인", role: .cancel) {} }
    }

    private var isValid: Bool { !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmation }
    private var errorAlert: Binding<Bool> { Binding(get: { error != nil }, set: { if !$0 { error = nil } }) }
    @MainActor private func changePassword() async {
        isSubmitting = true; defer { isSubmitting = false }
        do { try await HGAuthenticationService().changePassword(currentPassword: currentPassword, newPassword: newPassword); isComplete = true; currentPassword = ""; newPassword = ""; confirmation = "" }
        catch { self.error = HGErrorPresentation(error: error) }
    }
}
