import SwiftUI

struct HGPhotoWeatherInput: View {
    @Binding var temperature: String
    @Binding var humidity: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("현장 온도·습도")
                .font(HGFont.semiBold(16))
                .foregroundStyle(HGColor.primaryText)

            Text("현장 날씨를 불러올 수 없어 저장 전 측정값을 입력해주세요.")
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)

            HStack(spacing: 8) {
                inputField("온도 (°C)", placeholder: "예: 30", text: $temperature, keyboard: .decimalPad)
                inputField("습도 (%)", placeholder: "예: 60", text: $humidity, keyboard: .decimalPad)
            }
        }
        .padding(HGLayout.cardPadding)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.surfaceCardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HGLayout.surfaceCardCornerRadius)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
    }

    private func inputField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.medium(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(HGFont.regular(13, relativeTo: .caption))
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(HGColor.metricBackground, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func validatedValues(
        temperature: String,
        humidity: String
    ) -> (temperature: Double, humidity: Double)? {
        guard let temperature = Double(temperature.trimmingCharacters(in: .whitespacesAndNewlines)),
              let humidity = Double(humidity.trimmingCharacters(in: .whitespacesAndNewlines)),
              temperature.isFinite, (-50...60).contains(temperature),
              humidity.isFinite, (0...100).contains(humidity) else {
            return nil
        }
        return (temperature, humidity)
    }
}

#Preview {
    HGPhotoWeatherInput(temperature: .constant("30"), humidity: .constant("60"))
        .padding()
        .background(HGColor.appBackground)
}
