import SwiftUI

struct HGManualInputCard: View {
    @Binding private var isEnabled: Bool
    private let isLocked: Bool
    @Binding private var temperature: String
    @Binding private var humidity: String

    init(
        isEnabled: Binding<Bool>,
        temperature: Binding<String> = .constant(""),
        humidity: Binding<String> = .constant(""),
        isLocked: Bool = false
    ) {
        _isEnabled = isEnabled
        _temperature = temperature
        _humidity = humidity
        self.isLocked = isLocked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("온도계 데이터 직접 입력")
                    .font(HGFont.bold(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)

                Spacer()

                Toggle("온도계 데이터 직접 입력", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(HGColor.primary)
                    .disabled(isLocked)
            }

            HStack(spacing: 8) {
                inputField(title: "온도 (°C)", placeholder: "예: 47.5", text: $temperature, keyboardType: .decimalPad)
                inputField(title: "습도 (%)", placeholder: "예: 55", text: $humidity, keyboardType: .numberPad)
                calculatedField
            }
            .padding(.top, 16)

            Text(footerText)
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
                .padding(.top, 18)
        }
        .padding(20)
        .opacity(isLocked ? 0.5 : 1)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
        .disabled(!isEnabled || isLocked)
        .accessibilityElement(children: .contain)
        .keyboardDismissToolbar()
    }

    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.medium(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)

            TextField(placeholder, text: text)
                .font(HGFont.regular(13, relativeTo: .caption))
                .keyboardType(keyboardType)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(HGColor.metricBackground, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calculatedField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("체감온도 (°C)")
                .font(HGFont.medium(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)

            Text("자동 계산")
                .font(HGFont.regular(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(HGColor.metricBackground, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBackground: Color {
        isLocked ? HGColor.metricBackground : HGColor.surface
    }

    private var footerText: String {
        isLocked ? "저장이 확정되면 수정할 수 없습니다." : "미설치 시 자동으로 기록됩니다."
    }
}

#Preview {
    HGManualInputCard(
        isEnabled: .constant(true),
        temperature: .constant("47.5"),
        humidity: .constant("55")
    )
    .padding()
    .background(HGColor.appBackground)
}
