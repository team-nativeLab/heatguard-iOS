import SwiftUI

struct EmergencyCallView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let contact: HGEmergencyContact
    let isCancelling: Bool
    @Binding var error: HGErrorPresentation?
    let onPhoneCall: () -> Void
    let onCancel: () -> Void

    init(
        isCancelling: Bool = false,
        contact: HGEmergencyContact = .siteManager,
        error: Binding<HGErrorPresentation?> = .constant(nil),
        onPhoneCall: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        self.isCancelling = isCancelling
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
                .disabled(isCancelling)
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
                if !reduceMotion {
                    HGEmergencyPulse(delay: 0)
                    HGEmergencyPulse(delay: 0.9)
                }
                Circle().fill(HGColor.emergencyCallForeground).frame(width: 110, height: 110)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }

            Text("긴급 호출 중...")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.emergencyCallText)

            Text("긴급 호출이 등록됐어요.\n전화는 아래 본사 연락처를 눌러주세요.")
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

private struct HGEmergencyPulse: View {
    @State private var isExpanded = false

    let delay: Double

    var body: some View {
        Circle()
            .fill(HGColor.emergencyCallBackground)
            .frame(width: 138, height: 138)
            .scaleEffect(isExpanded ? 1.65 : 1)
            .opacity(isExpanded ? 0 : 0.8)
            .animation(
                .easeOut(duration: 1.8)
                    .delay(delay)
                    .repeatForever(autoreverses: false),
                value: isExpanded
            )
            .onAppear { isExpanded = true }
            .accessibilityHidden(true)
    }
}
