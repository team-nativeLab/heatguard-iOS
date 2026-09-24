import SwiftUI

struct EmergencyCallView: View {
    private let contact = HGEmergencyContact.siteManager
    let onCancel: () -> Void

    init(onCancel: @escaping () -> Void = {}) {
        self.onCancel = onCancel
    }

    var body: some View {
        HGStatusPopup(title: "긴급 호출") {
            emergencyNotice
                .padding(.top, 48)

            callStatus
                .padding(.top, 17)

            contactCard
                .padding(.top, 28)
        } actions: {
            HGSecondaryButton(title: "호출 취소", action: onCancel)
                .padding(.horizontal, 28)
        }
    }

    private var emergencyNotice: some View {
        HGEmergencyNotice()
    }

    private var callStatus: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(HGColor.emergencyCallBackground).frame(width: 138, height: 138)
                Circle().fill(HGColor.emergencyCallForeground).frame(width: 110, height: 110)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }

            Text("긴급 호출 중...")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.emergencyCallText)

            Text("버튼을 누르면 즉시\n관리자에게 전화가 연결됩니다")
                .font(HGFont.semiBold(15))
                .foregroundStyle(HGColor.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var contactCard: some View {
        HGEmergencyContactCard(contact: contact)
    }
}
