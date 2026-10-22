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
                HGTextField(
                    title: "온도 (°C)",
                    placeholder: "예: 30",
                    text: $temperature,
                    fieldHeight: 40,
                    cornerRadius: 10,
                    textSize: 13,
                    inputType: .decimal,
                    style: .compact
                )
                HGTextField(
                    title: "습도 (%)",
                    placeholder: "예: 60",
                    text: $humidity,
                    fieldHeight: 40,
                    cornerRadius: 10,
                    textSize: 13,
                    inputType: .decimal,
                    style: .compact
                )
            }
        }
        .padding(HGLayout.cardPadding)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.surfaceCardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HGLayout.surfaceCardCornerRadius)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
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
