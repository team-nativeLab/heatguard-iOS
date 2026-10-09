import SwiftUI

struct WithdrawalCompletedView: View {
    let onConfirm: () -> Void

    var body: some View {
        HGStatusPopup(title: "회원탈퇴") {
            completionCard
                .padding(.top, 48)
                .padding(.horizontal, HGLayout.screenHorizontalPadding)
        } actions: {
            HGPrimaryButton(title: "확인", action: onConfirm)
                .padding(.horizontal, HGLayout.screenHorizontalPadding)
        }
    }

    private var completionCard: some View {
        HGCard(cornerRadius: HGLayout.popupCornerRadius, padding: 28) {
            VStack(spacing: 0) {
                Image(systemName: "checkmark")
                    .font(HGFont.notoBold(30, relativeTo: .title))
                    .foregroundStyle(HGColor.primary)
                    .frame(width: 84, height: 84)
                    .background(HGColor.homeMetricIconBackground, in: Circle())

                Text("탈퇴가 완료되었어요")
                    .font(HGFont.notoBold(20, relativeTo: .title3))
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.top, 24)

                Text("그동안 현장가드를 이용해주셔서 감사해요")
                    .font(HGFont.notoMedium(15, relativeTo: .subheadline))
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
