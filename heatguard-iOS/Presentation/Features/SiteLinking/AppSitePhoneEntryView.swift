import SwiftUI

struct AppSitePhoneEntryView: View {
    let onSubmit: (String) -> Void
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPhoneFieldFocused: Bool
    @State private var phoneNumber = ""

    private var digits: String {
        phoneNumber.filter(\.isNumber)
    }

    private var isValidPhoneNumber: Bool {
        (9...11).contains(digits.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text("휴대폰 번호를\n입력해주세요")
                    .font(HGFont.bold(26, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)
                    .lineSpacing(0)

                Text("관리자와 합의한 전화번호로 인증해주세요.")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("휴대폰 번호")
                        .font(HGFont.bold(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.primaryText)

                    phoneField
                }
                .padding(.top, 36)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 14, weight: .medium))
                    Text("번호는 본인 확인에만 사용되고 안전하게 보관돼요")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255))
                .padding(.top, 10)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 26)

            Button {
                isPhoneFieldFocused = false
                onSubmit(digits)
            } label: {
                Text("연동하기")
                    .font(HGFont.bold(16, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 59 / 255, green: 140 / 255, blue: 245 / 255),
                                Color(red: 31 / 255, green: 111 / 255, blue: 224 / 255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: HGColor.primary.opacity(0.28), radius: 10, y: 8)
            }
            .disabled(!isValidPhoneNumber)
            .opacity(isValidPhoneNumber ? 1 : 0.55)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .dismissKeyboardOnBackgroundTap()
        .background(HGColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }

    private var header: some View {
        ZStack {
            HStack {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HGColor.primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")

                Spacer()
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
    }

    private var phoneField: some View {
        HStack(spacing: 12) {
            Text("+82")
                .font(HGFont.medium(15, relativeTo: .body))
                .foregroundStyle(HGColor.secondaryText)

            Rectangle()
                .fill(Color(red: 232 / 255, green: 235 / 255, blue: 245 / 255))
                .frame(width: 1, height: 18)

            TextField("휴대폰 번호", text: $phoneNumber)
                .font(HGFont.bold(17, relativeTo: .body))
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($isPhoneFieldFocused)
                .tracking(0.34)
                .onChange(of: phoneNumber) { _, value in
                    let normalized = String(value.filter { $0.isNumber || $0 == "-" }.prefix(13))
                    if normalized != value { phoneNumber = normalized }
                }
                .accessibilityLabel("전화번호")

            if !phoneNumber.isEmpty {
                Button { phoneNumber = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(HGColor.placeholder)
                }
                .accessibilityLabel("전화번호 지우기")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isPhoneFieldFocused ? HGColor.primary : HGColor.inputBorder, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: isPhoneFieldFocused ? HGColor.primary.opacity(0.12) : .clear, radius: 4)
    }
}

#Preview {
    NavigationStack {
        AppSitePhoneEntryView(onSubmit: { _ in })
    }
}
