import SwiftUI

struct WithdrawalConfirmationDialog: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "exclamationmark")
                .font(HGFont.bold(28, relativeTo: .title))
                .foregroundStyle(.red)
                .frame(width: 64, height: 64)
                .background(HGColor.error.opacity(0.12), in: Circle())

            Text("정말 탈퇴하시겠어요?")
                .font(HGFont.bold(19, relativeTo: .title3))
                .foregroundStyle(HGColor.primaryText)
                .padding(.top, 22)

            Text("탈퇴하면 계정 정보가 즉시 삭제되며\n다시 되돌릴 수 없어요.")
                .font(HGFont.regular(13, relativeTo: .subheadline))
                .foregroundStyle(HGColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 8)

            HStack(spacing: 8) {
                dialogButton(title: "취소", foreground: HGColor.primaryText, background: HGColor.metricBackground, action: onCancel)
                dialogButton(title: "탈퇴하기", foreground: .white, background: .red, action: onConfirm)
            }
            .padding(.top, 26)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.popupCornerRadius))
        .padding(.horizontal, 38)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("회원탈퇴 최종 확인")
    }

    private func dialogButton(
        title: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(HGFont.semiBold(14, relativeTo: .subheadline))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: HGLayout.inputCardCornerRadius))
    }
}

#Preview {
    ZStack {
        HGColor.appBackground.ignoresSafeArea()
        WithdrawalConfirmationDialog(onCancel: {}, onConfirm: {})
    }
}
