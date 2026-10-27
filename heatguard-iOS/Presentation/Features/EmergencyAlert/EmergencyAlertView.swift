import SwiftUI

struct EmergencyAlertView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isCalling: Bool
    let contact: HGEmergencyContact
    @Binding var error: HGErrorPresentation?
    let onPhoneCall: () -> Void
    let onCall: () -> Void

    init(
        isCalling: Bool = false,
        contact: HGEmergencyContact = .siteManager,
        error: Binding<HGErrorPresentation?> = .constant(nil),
        onPhoneCall: @escaping () -> Void = {},
        onCall: @escaping () -> Void = {}
    ) {
        self.isCalling = isCalling
        self.contact = contact
        _error = error
        self.onPhoneCall = onPhoneCall
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
            HGSecondaryButton(title: isCalling ? "호출 중..." : "호출하기", action: onCall)
                .disabled(isCalling)
                .padding(.horizontal, 28)
        }
        .alert(error?.title ?? "본사 전화 오류", isPresented: errorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private var emergencyNotice: some View {
        HGEmergencyNotice()
    }

    private var callPrompt: some View {
        VStack(spacing: 12) {
            ZStack {
                if !reduceMotion {
                    HGEmergencyPulse(delay: 0, color: HGColor.emergencyAlertPulse)
                    HGEmergencyPulse(delay: 0.9, color: HGColor.emergencyAlertPulse)
                }

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

            Text("호출하기를 누르면 긴급 호출을 등록해요.\n전화는 아래 본사 연락처를 눌러주세요.")
                .font(HGFont.semiBold(15))
                .foregroundStyle(HGColor.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var contactCard: some View {
        HGEmergencyContactCard(contact: contact, onPhoneCall: onPhoneCall)
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

#Preview {
    EmergencyAlertView()
}
