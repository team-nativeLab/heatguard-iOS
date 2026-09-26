import SwiftUI

struct WithdrawalGuideView: View {
    let onRequestConfirmation: () -> Void

    @State private var selectedReason: WithdrawalReason?
    @State private var password = ""
    @State private var hasAgreed = false
    @State private var showsConfirmation = false

    init(onRequestConfirmation: @escaping () -> Void = {}) {
        self.onRequestConfirmation = onRequestConfirmation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("탈퇴하기 전에 꼭 확인해주세요")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)

                Text("탈퇴 후에는 아래 내용이 적용돼요")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.top, 6)

                noticeCard
                    .padding(.top, 16)

                reasonCard
                    .padding(.top, 16)

                HGTextField(
                    title: "비밀번호 확인",
                    placeholder: "현재 비밀번호를 입력해주세요",
                    text: $password,
                    isSecure: true
                )
                .padding(.top, 18)

                agreementRow
                    .padding(.top, 20)
            }
            .padding(.horizontal, HGLayout.screenHorizontalPadding)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .background(HGColor.appBackground)
        .navigationTitle("회원탈퇴")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HGPrimaryButton(title: "탈퇴하기", isEnabled: canRequestWithdrawal) {
                showsConfirmation = true
            }
                .padding(.horizontal, HGLayout.screenHorizontalPadding)
                .padding(.vertical, 14)
                .background(HGColor.appBackground)
        }
        .overlay {
            if showsConfirmation {
                ZStack {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()
                        .onTapGesture(perform: dismissConfirmation)

                    WithdrawalConfirmationDialog(
                        onCancel: dismissConfirmation,
                        onConfirm: confirmWithdrawal
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsConfirmation)
        .dismissKeyboardOnBackgroundTap()
    }

    private var noticeCard: some View {
        HGCard(cornerRadius: 18, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(HGColor.error)
                    Text("유의사항")
                        .foregroundStyle(HGColor.primaryText)
                }
                .font(HGFont.bold(14, relativeTo: .subheadline))

                VStack(alignment: .leading, spacing: 10) {
                    noticeText("계정 정보(이름, 이메일, 회사명)는 즉시 삭제되며 복구할 수 없어요")
                    noticeText("온도계 기록·현장 사진 등 작업 기록은 관계 법령에 따라 회사에 일정 기간 보관될 수 있어요")
                    noticeText("탈퇴 후 같은 이메일로 다시 가입해도 이전 기록은 연결되지 않아요")
                }
            }
        }
    }

    private var reasonCard: some View {
        HGCard(cornerRadius: 18, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("탈퇴 사유")
                        .font(HGFont.bold(14, relativeTo: .subheadline))
                        .foregroundStyle(HGColor.primaryText)
                    Text("(선택)")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                }

                VStack(spacing: 14) {
                    ForEach(WithdrawalReason.allCases) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedReason == reason ? "largecircle.fill.circle" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedReason == reason ? HGColor.primary : HGColor.inputBorder)
                                Text(reason.title)
                                    .font(HGFont.medium(14, relativeTo: .subheadline))
                                    .foregroundStyle(HGColor.primaryText)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var agreementRow: some View {
        Button {
            hasAgreed.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(hasAgreed ? HGColor.primary : HGColor.inputBorder)
                Text("유의사항을 모두 확인했으며, 탈퇴에 동의해요")
                    .font(HGFont.medium(13, relativeTo: .caption))
                    .foregroundStyle(HGColor.primaryText)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var canRequestWithdrawal: Bool {
        selectedReason != nil && !password.isEmpty && hasAgreed
    }

    private func dismissConfirmation() {
        showsConfirmation = false
    }

    private func confirmWithdrawal() {
        showsConfirmation = false
        onRequestConfirmation()
    }

    private func noticeText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text("•")
            Text(text)
        }
        .font(HGFont.regular(12, relativeTo: .caption))
        .foregroundStyle(HGColor.secondaryText)
    }
}

private enum WithdrawalReason: CaseIterable, Identifiable {
    case workEnded
    case changedCompany
    case inconvenientApp
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .workEnded: "현장 작업이 종료되었어요"
        case .changedCompany: "다른 회사로 이직했어요"
        case .inconvenientApp: "앱 사용이 불편해요"
        case .other: "기타"
        }
    }
}

#Preview {
    NavigationStack {
        WithdrawalGuideView()
    }
}
