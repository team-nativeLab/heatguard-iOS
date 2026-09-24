//
//  ThermometerRecordView.swift
//  heatguard-iOS
//

import SwiftUI

struct ThermometerRecordView: View {
    @State private var isManualEntryEnabled = false
    @State private var temperature = "47.5"
    @State private var humidity = "55"
    @State private var apparentTemperature = 40.5

    let onContinue: (HGRecordDraft) -> Void

    init(
        onContinue: @escaping (HGRecordDraft) -> Void = { _ in }
    ) {
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("온도계 기록")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(.black)

                Text("온도계 데이터를 입력하고 현장 사진을\n촬영해 주세요.")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(.black)
                    .padding(.top, 10)

                temperatureSummaryCard
                    .padding(.top, 25)

                manualEntryCard
                    .padding(.top, 30)

                photoSection
                    .padding(.top, 26)
            }
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(title: "기록 저장", height: 48, action: continueToPhoto)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardOnBackgroundTap()
    }

    private var header: some View {
        HGScreenHeader()
    }

    private var temperatureSummaryCard: some View {
        HStack(spacing: 15) {
            Image("ThermometerIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 76)

            VStack(alignment: .leading, spacing: 0) {
                Text("현재 온도")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                    .foregroundStyle(summaryText)

                Text("\(temperature) °C")
                    .font(HGFont.bold(32, relativeTo: .largeTitle))
                    .foregroundStyle(.black)
                    .padding(.top, 9)

                Text("습도 \(humidity)% · 체감 \(apparentTemperature.formatted(.number.precision(.fractionLength(1)))) °C")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                    .foregroundStyle(summaryText)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 138, maxHeight: 138)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: HGColor.cardShadow.opacity(0.25), radius: 7.3, x: 4, y: 4)
    }

    private var manualEntryCard: some View {
        HGManualInputCard(
            isEnabled: $isManualEntryEnabled,
            temperature: $temperature,
            humidity: $humidity
        )
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("현장 사진")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(.black)

            Button(action: continueToPhoto) {
                HStack(spacing: 0) {
                    Image("camera")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .padding(.leading, 19)

                    Spacer()

                    Text("사진 촬영 또는\n앨범에서 선택")
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(summaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 79)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HGColor.inputBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("현장 사진 선택")
        }
    }

    private var summaryText: Color {
        HGColor.summaryText
    }

    private func continueToPhoto() {
        UIApplication.shared.dismissKeyboard()
        guard
            let inputTemperature = Double(temperature),
            let inputHumidity = Double(humidity)
        else { return }

        continueWithRecord(temperature: inputTemperature, humidity: inputHumidity)
    }

    private func continueWithRecord(temperature: Double, humidity: Double) {
        onContinue(HGRecordDraft(type: .thermometer, memo: "", temperature: temperature, humidity: humidity))
    }

}

#Preview {
    NavigationStack {
        ThermometerRecordView()
    }
}
