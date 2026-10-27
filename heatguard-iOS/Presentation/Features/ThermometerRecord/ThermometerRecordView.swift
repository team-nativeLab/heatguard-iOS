//
//  ThermometerRecordView.swift
//  heatguard-iOS
//

import SwiftUI

struct ThermometerRecordView: View {
    @State private var isManualEntryEnabled = false
    @State private var isKeyboardVisible = false
    @State private var temperature: String
    @State private var humidity: String
    private let automaticMeasurement: HGWeatherMeasurement?
    private let teamName: String?
    private let workplace: String?
    private let siteName: String?
    @State private var validationMessage: String?

    let onContinue: (HGRecordDraft) -> Void
    let onNotificationsTap: () -> Void
    let notificationCount: Int

    init(
        weather: HomeWeather = .unavailable,
        teamName: String? = nil,
        workplace: String? = nil,
        siteName: String? = nil,
        onContinue: @escaping (HGRecordDraft) -> Void = { _ in },
        onNotificationsTap: @escaping () -> Void = {},
        notificationCount: Int = 0
    ) {
        _temperature = State(initialValue: weather.temperature.map { String(format: "%.1f", $0) } ?? "")
        _humidity = State(initialValue: weather.humidity.map { String(format: "%.0f", $0) } ?? "")
        automaticMeasurement = {
            guard let temperature = weather.temperature, let humidity = weather.humidity else { return nil }
            return HGWeatherMeasurement(temperature: temperature, humidity: humidity)
        }()
        self.teamName = teamName
        self.workplace = workplace
        self.siteName = siteName
        self.onContinue = onContinue
        self.onNotificationsTap = onNotificationsTap
        self.notificationCount = notificationCount
    }

    var body: some View {
        HGFixedContent(keyboardAware: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text("온도계 기록")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)

                Text("온도계 데이터를 입력하고 현장 사진을\n촬영해 주세요.")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.top, 10)

                temperatureSummaryCard
                    .padding(.top, 25)

                manualEntryCard
                    .padding(.top, 30)

                photoSection
                    .padding(.top, 26)
            }
            .padding(.top, HGLayout.screenContentTopPadding)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
        .padding(.top, 8)
        .background(HGColor.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isKeyboardVisible {
                HGPrimaryButton(title: "기록 저장", action: continueToPhoto)
                    .padding(.horizontal, HGLayout.screenHorizontalPadding + 4)
                    .padding(.vertical, 8)
                    .background(HGColor.appBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = false }
        }
        .hgRouteNavigationHeader(notificationCount: notificationCount, onNotificationsTap: onNotificationsTap)
        .dismissKeyboardOnBackgroundTap()
        .alert("입력값을 확인해주세요", isPresented: validationAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private var temperatureSummaryCard: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 82)

                VStack(alignment: .leading, spacing: 0) {
                    Text("현재 온도")
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(summaryText)

                    Text(displayedTemperature)
                        .font(HGFont.bold(32, relativeTo: .largeTitle))
                        .foregroundStyle(HGColor.primaryText)
                        .padding(.top, 9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(
                        "습도 \(displayedHumidity) · 체감 " +
                            (displayedApparentTemperature.map {
                                $0.formatted(.number.precision(.fractionLength(1))) + " °C"
                            } ?? "—")
                    )
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(summaryText)
                        .padding(.top, 14)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Image("ThermometerIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .offset(x: -16, y: -10)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 124, maxHeight: 124)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.inputCardCornerRadius))
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
                .foregroundStyle(HGColor.primaryText)

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

    private var manualMeasurement: HGWeatherMeasurement? {
        HGWeatherMeasurement(temperatureText: temperature, humidityText: humidity)
    }

    private var displayedMeasurement: HGWeatherMeasurement? {
        isManualEntryEnabled ? manualMeasurement : automaticMeasurement
    }

    private var displayedApparentTemperature: Double? {
        displayedMeasurement?.apparentTemperature
    }

    private var displayedTemperature: String {
        guard let displayedMeasurement else { return "—" }
        let value = isManualEntryEnabled ? temperature : String(format: "%.1f", displayedMeasurement.temperature)
        return "\(value) °C"
    }

    private var displayedHumidity: String {
        guard let displayedMeasurement else { return "—" }
        let value = isManualEntryEnabled ? humidity : String(format: "%.0f", displayedMeasurement.humidity)
        return "\(value)%"
    }

    private func continueToPhoto() {
        UIApplication.shared.dismissKeyboard()
        guard let measurement = displayedMeasurement else {
            validationMessage = isManualEntryEnabled
                ? "온도는 -50~60°C, 습도는 0~100% 범위의 숫자로 입력해주세요."
                : "자동 측정값이 없습니다. 직접 입력을 켜고 온도와 습도를 입력해주세요."
            return
        }

        continueWithRecord(temperature: measurement.temperature, humidity: measurement.humidity)
    }

    private func continueWithRecord(temperature: Double, humidity: Double) {
        onContinue(HGRecordDraft(
            type: .thermometer,
            memo: "",
            temperature: temperature,
            humidity: humidity,
            teamName: teamName,
            workplace: workplace,
            siteName: siteName
        ))
    }

    private var validationAlert: Binding<Bool> { Binding(get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } }) }

}

#Preview {
    NavigationStack {
        ThermometerRecordView()
    }
}
