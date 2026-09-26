import SwiftUI

struct WithdrawalCompletedView: View {
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            completionCard
                .padding(.top, 48)

            Spacer()
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
        .background(HGColor.appBackground)
        .navigationTitle("회원탈퇴")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HGPrimaryButton(title: "확인", action: onConfirm)
                .padding(.horizontal, HGLayout.screenHorizontalPadding)
                .padding(.vertical, 14)
                .background(HGColor.appBackground)
        }
    }

    private var completionCard: some View {
        HGCard(cornerRadius: HGLayout.popupCornerRadius, padding: 28) {
            VStack(spacing: 0) {
                Image(systemName: "checkmark")
                    .font(HGFont.bold(30, relativeTo: .title))
                    .foregroundStyle(HGColor.primary)
                    .frame(width: 72, height: 72)
                    .background(HGColor.homeMetricIconBackground, in: Circle())

                Text("탈퇴가 완료되었어요")
                    .font(HGFont.bold(19, relativeTo: .title3))
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.top, 24)

                Text("그동안 폭염가드를 이용해주셔서 감사해요")
                    .font(HGFont.regular(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        WithdrawalCompletedView(onConfirm: {})
    }
}
