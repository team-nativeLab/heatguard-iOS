import SwiftUI

struct EmergencyCallView: View {
    private let contact: HGEmergencyContact
    let isCancelling: Bool
    let canCancel: Bool
    @Binding var error: HGErrorPresentation?
    let onPhoneCall: () -> Void
    let onCancel: () -> Void

    init(
        isCancelling: Bool = false,
        canCancel: Bool = true,
        contact: HGEmergencyContact = .siteManager,
        error: Binding<HGErrorPresentation?> = .constant(nil),
        onPhoneCall: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        self.isCancelling = isCancelling
        self.canCancel = canCancel
        self.contact = contact
        _error = error
        self.onPhoneCall = onPhoneCall
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
            HGSecondaryButton(title: isCancelling ? "취소 중..." : "호출 취소", action: onCancel)
                .disabled(isCancelling || !canCancel)
                .padding(.horizontal, 28)
        }
        .alert(error?.title ?? "긴급 호출 오류", isPresented: errorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
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
        HGEmergencyContactCard(contact: contact, onPhoneCall: onPhoneCall)
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}
