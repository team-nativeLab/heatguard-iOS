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
    var onPhoneCall: () -> Void = {}

    var body: some View {
        HGPopupCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("연락 대상")
                    .font(HGFont.bold(15))
                Text(contact.name)
                    .font(HGFont.bold(16, relativeTo: .headline))

                HStack {
                    if let phoneNumber = contact.phoneNumber, !phoneNumber.isEmpty {
                        Button(action: onPhoneCall) {
                            HStack {
                                Text(phoneNumber)
                                    .font(HGFont.bold(16, relativeTo: .headline))
                                    .foregroundStyle(HGColor.primary)
                                Spacer()
                                Image("Phone")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(contact.phoneNumber?.telephoneURL == nil)
                    } else {
                        Text("연락처 정보 없음")
                            .font(HGFont.medium(13, relativeTo: .caption))
                            .foregroundStyle(HGColor.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 103, alignment: .leading)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
    }
}

struct HGEmergencyContact {
    let name: String
    let phoneNumber: String?

    static let siteManager = HGEmergencyContact(
        name: "현장 관리자",
        phoneNumber: nil
    )
}

extension String {
    var telephoneURL: URL? {
        let allowedCharacters = CharacterSet(charactersIn: "+0123456789")
        let sanitized = unicodeScalars.filter(allowedCharacters.contains).map(String.init).joined()
        let digits = sanitized.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        let normalized = sanitized.hasPrefix("+") ? "+" + digits : digits
        return URL(string: "tel:\(normalized)")
    }
}
