import SwiftUI

struct AppSitePhoneEntryView: View {
    let onSubmit: (String) -> Void
    var onBack: (() -> Void)?
    var busy = false

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
                Text("현장 연동 인증")
                    .font(HGFont.bold(25, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.top, 48)

                Text("현장 관리자에게 등록된 전화번호를 입력해주세요.")
                    .font(HGFont.regular(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.top, 10)

                phoneField
                    .padding(.top, 32)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 14, weight: .medium))
                    Text("전화번호는 본인 확인에만 사용되고 안전하게 보관돼요.")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(HGColor.secondaryText)
                .padding(.top, 14)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            HGPrimaryButton(title: busy ? "연동 중..." : "연동하기", isEnabled: isValidPhoneNumber && !busy) {
                isPhoneFieldFocused = false
                onSubmit(digits)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .dismissKeyboardOnBackgroundTap()
        .background(HGColor.surface.ignoresSafeArea())
        .disabled(busy)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }

    private var header: some View {
        ZStack {
            Text("현장 연동")
                .font(HGFont.semiBold(18, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)

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
                .font(HGFont.medium(16, relativeTo: .body))
                .foregroundStyle(HGColor.primaryText)

            Rectangle()
                .fill(HGColor.inputBorder)
                .frame(width: 1, height: 24)

            TextField("휴대폰 번호", text: $phoneNumber)
                .font(HGFont.regular(16, relativeTo: .body))
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($isPhoneFieldFocused)
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
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPhoneFieldFocused ? HGColor.primary : HGColor.inputBorder, lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        AppSitePhoneEntryView(onSubmit: { _ in })
    }
}
