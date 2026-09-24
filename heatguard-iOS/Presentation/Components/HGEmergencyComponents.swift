import SwiftUI

struct HGEmergencyNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("긴급 상황이에요")
                .font(HGFont.bold(16))
            Text("현장관리자에게 즉시 도움을 요청합니다")
                .font(HGFont.semiBold(12, relativeTo: .caption))
        }
        .foregroundStyle(HGColor.emergencyNoticeText)
        .frame(maxWidth: .infinity, minHeight: 73, alignment: .leading)
        .padding(.horizontal, 19)
        .background(
            HGColor.emergencyNoticeBackground,
            in: RoundedRectangle(cornerRadius: HGLayout.popupCornerRadius)
        )
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
    }
}

struct HGEmergencyContactCard: View {
    let contact: HGEmergencyContact

    var body: some View {
        HGPopupCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("연락 대상")
                    .font(HGFont.bold(15))
                Text(contact.name)
                    .font(HGFont.bold(16, relativeTo: .headline))

                HStack {
                    Text(contact.phoneNumber)
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
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
    }
}

struct HGEmergencyContact {
    let name: String
    let phoneNumber: String

    static let siteManager = HGEmergencyContact(
        name: "현장 관리자",
        phoneNumber: "010 - 1234 - 5678"
    )
}
