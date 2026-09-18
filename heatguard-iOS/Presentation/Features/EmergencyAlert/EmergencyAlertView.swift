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
        VStack(alignment: .leading, spacing: 8) {
            Text("긴급 상황이에요")
                .font(HGFont.bold(16))
            Text("현장관리자에게 즉시 도움을 요청합니다")
                .font(HGFont.semiBold(12, relativeTo: .caption))
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, minHeight: 73, alignment: .leading)
        .padding(.horizontal, 19)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 25))
        .padding(.horizontal, 25)
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
                .foregroundStyle(.red)

            Text("버튼을 누르면 즉시\n관리자에게 전화가 연결됩니다")
                .font(HGFont.semiBold(15))
                .foregroundStyle(HGColor.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var contactCard: some View {
        HGPopupCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("연락 대상")
                    .font(HGFont.bold(15))

                Text("현장 관리자")
                    .font(HGFont.bold(16, relativeTo: .headline))

                HStack {
                    Text("010 - 1234 - 5678")
                        .font(HGFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(HGColor.primary)
                    Spacer()
                    Image("Phone")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 103, alignment: .leading)
        }
        .padding(.horizontal, 25)
    }
}

#Preview {
    EmergencyAlertView()
}
