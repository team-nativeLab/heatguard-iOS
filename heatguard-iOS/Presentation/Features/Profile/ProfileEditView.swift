import SwiftUI

struct ProfileEditView: View {
    let profile: HGTeamProfile?
    @State private var company: String
    @State private var name: String
    @State private var showsUnsupportedMessage = false

    init(profile: HGTeamProfile? = nil) {
        self.profile = profile
        _company = State(initialValue: "이음산업건설")
        _name = State(initialValue: profile?.name ?? "김현장")
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
                    HGTextField(title: "회사명", placeholder: "회사명을 입력해주세요", text: $company, fieldHeight: 48)
                    HGTextField(title: "이름", placeholder: "이름을 입력해주세요", text: $name, fieldHeight: 48)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("이메일").font(HGFont.semiBold(13, relativeTo: .caption)).foregroundStyle(HGColor.primaryText)
                        HStack { Text(profile?.email ?? "worker@ieum.co.kr").foregroundStyle(HGColor.secondaryText); Spacer(); Text("변경 불가").font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText) }
                            .font(HGFont.regular(14)).padding(.horizontal, 16).frame(height: 48).background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12))
                        Text("로그인에 쓰는 이메일은 변경할 수 없어요").font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
                    }
                    NavigationLink { PasswordChangeView() } label: {
                        HStack { VStack(alignment: .leading, spacing: 3) { Text("비밀번호 변경").font(HGFont.semiBold(14, relativeTo: .subheadline)); Text("현재 비밀번호 확인 후 변경할 수 있어요").font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(HGColor.homeChevron) }
                            .padding(16).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).foregroundStyle(HGColor.primaryText)
                }
            }.padding(24)
        }
        .background(HGColor.appBackground).navigationTitle("내 정보 수정").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { HGPrimaryButton(title: "저장하기") { showsUnsupportedMessage = true }.padding(.horizontal, 28).padding(.vertical, 10).background(HGColor.appBackground) }
        .alert("아직 저장할 수 없습니다.", isPresented: $showsUnsupportedMessage) { Button("확인", role: .cancel) {} } message: { Text("회사명과 이름을 변경하는 작업자 API가 준비되면 저장할 수 있어요.") }
        .dismissKeyboardOnBackgroundTap().keyboardDismissToolbar()
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
        }.padding(24).background(HGColor.appBackground).navigationTitle("비밀번호 변경").navigationBarTitleDisplayMode(.inline).dismissKeyboardOnBackgroundTap().keyboardDismissToolbar()
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
