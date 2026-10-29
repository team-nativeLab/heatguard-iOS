import SwiftUI

struct EmergencyCallView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
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
            callStatus
                .padding(.top, 48)

            contactCard
                .padding(.top, 28)
        } actions: {
            HGSecondaryButton(
                title: isCancelling ? "취소 중..." : canCancel ? "호출 취소" : "접수 완료",
                action: onCancel
            )
                .disabled(isCancelling || !canCancel)
                .padding(.horizontal, 28)
        }
        .alert(error?.title ?? "긴급 호출 오류", isPresented: errorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private var callStatus: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(HGColor.emergencyCallBackground).frame(width: 138, height: 138)
                if !reduceMotion {
                    HGEmergencyPulse(delay: 0, color: HGColor.emergencyCallBackground)
                    HGEmergencyPulse(delay: 0.9, color: HGColor.emergencyCallBackground)
                }
                Circle().fill(HGColor.emergencyCallForeground).frame(width: 110, height: 110)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }

            Text(canCancel ? "긴급 호출 중..." : "긴급 호출 접수됨")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.emergencyCallText)

            Text(
                canCancel
                    ? "긴급 호출이 등록됐어요.\n전화는 아래 본사 연락처를 눌러주세요."
                    : "현장 관리자가 호출을 접수했어요.\n앱에서 취소할 수 없습니다."
            )
                .font(HGFont.semiBold(15))
                .foregroundStyle(HGColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.88)
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .onAppear {
            guard !hasAppeared else { return }
            guard !reduceMotion else {
                hasAppeared = true
                return
            }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) {
                hasAppeared = true
            }
        }
    }

    private var contactCard: some View {
        HGEmergencyContactCard(contact: contact, onPhoneCall: onPhoneCall)
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}
