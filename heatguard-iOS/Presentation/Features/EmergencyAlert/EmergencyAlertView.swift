import SwiftUI

struct EmergencyAlertView: View {
    let onCall: () -> Void

    init(onCall: @escaping () -> Void = {}) {
        self.onCall = onCall
    }

    var body: some View {
        HGStatusPopup(title: "긴급 호출") {
            emergencyNotice
                .padding(.top, 33)

            callPrompt
                .padding(.top, 17)

            contactCard
                .padding(.top, 28)
        } actions: {
            HGSecondaryButton(title: "호출하기", action: onCall)
                .padding(.horizontal, 28)
        }
    }

    private var emergencyNotice: some View {
        HGEmergencyNotice()
    }

    private var callPrompt: some View {
        VStack(spacing: 12) {
            ZStack {
                Image("EmergencyOuterCircle")
                    .resizable()
                    .frame(width: 138, height: 138)

                Image("EmergencyInnerCircle")
                    .resizable()
                    .frame(width: 110, height: 110)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }

            Text("긴급 호출하기")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.emergencyNoticeText)

            Text("버튼을 누르면 즉시\n관리자에게 전화가 연결됩니다")
                .font(HGFont.semiBold(15))
                .foregroundStyle(HGColor.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var contactCard: some View {
        HGEmergencyContactCard(contact: .siteManager)
    }
}

#Preview {
    EmergencyAlertView()
}
