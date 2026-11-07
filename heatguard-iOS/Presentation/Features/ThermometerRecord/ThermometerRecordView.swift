//
//  ThermometerRecordView.swift
//  heatguard-iOS
//

import SwiftUI

struct ThermometerRecordView: View {
    @State private var isManualEntryEnabled = false
    @State private var isSaving = false
    @State private var temperature: String
    @State private var humidity: String
    private let automaticTemperature: Double?
    private let automaticHumidity: Double?
    private let teamName: String?
    private let workplace: String?
    private let siteName: String?
    @State private var validationMessage: String?

    let onContinue: (HGRecordDraft) -> Void
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void
    let onNotificationsTap: () -> Void
    let notificationCount: Int

    init(
        weather: HomeWeather = .unavailable,
        teamName: String? = nil,
        workplace: String? = nil,
        siteName: String? = nil,
        onContinue: @escaping (HGRecordDraft) -> Void = { _ in },
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in },
        onNotificationsTap: @escaping () -> Void = {},
        notificationCount: Int = 0
    ) {
        _temperature = State(initialValue: weather.temperature.map { String(format: "%.1f", $0) } ?? "")
        _humidity = State(initialValue: weather.humidity.map { String(format: "%.0f", $0) } ?? "")
        automaticTemperature = Self.validatedTemperature(weather.temperature)
        automaticHumidity = Self.validatedHumidity(weather.humidity)
        self.teamName = teamName
        self.workplace = workplace
        self.siteName = siteName
        self.onContinue = onContinue
        self.onSave = onSave
        self.onFailure = onFailure
        self.onNotificationsTap = onNotificationsTap
        self.notificationCount = notificationCount
    }

    var body: some View {
        HGFixedContent(keyboardAware: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text("온도계 기록")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)

                Text("온도계 데이터를 입력하고 필요하면 현장 사진을 추가해 주세요.")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.top, 10)

                temperatureSummaryCard
                    .padding(.top, 25)

                manualEntryCard
                    .padding(.top, 30)

                photoSection
                    .padding(.top, 34)
            }
            .padding(.top, HGLayout.screenContentTopPadding)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
        .padding(.top, 8)
        .background(HGColor.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HGPrimaryButton(
                title: isSaving ? "저장 중..." : "기록 저장",
                isEnabled: currentDraft != nil && !isSaving,
                isLoading: isSaving,
                action: saveRecord
            )
            .padding(.horizontal, HGLayout.screenHorizontalPadding + 4)
            .padding(.vertical, 8)
            .background(HGColor.appBackground)
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
                        .frame(width: 36, height: 36)
                        .padding(.leading, 18)

                    Spacer()

                    Text("사진 촬영 또는\n앨범에서 선택")
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(summaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 88)
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

    private var displayedApparentTemperature: Double? {
        guard let temperature = currentTemperature, let humidity = currentHumidity else { return nil }
        return HGWeatherMeasurement(temperature: temperature, humidity: humidity)?.apparentTemperature
    }

    private var displayedTemperature: String {
        guard let currentTemperature else { return "—" }
        let value = isManualEntryEnabled
            ? temperature.trimmingCharacters(in: .whitespacesAndNewlines)
            : String(format: "%.1f", currentTemperature)
        return "\(value) °C"
    }

    private var displayedHumidity: String {
        guard let currentHumidity else { return "—" }
        let value = isManualEntryEnabled
            ? humidity.trimmingCharacters(in: .whitespacesAndNewlines)
            : String(format: "%.0f", currentHumidity)
        return "\(value)%"
    }

    private func continueToPhoto() {
        UIApplication.shared.dismissKeyboard()
        guard let draft = currentDraft else {
            validationMessage = validationMessageForCurrentInput
            return
        }
        onContinue(draft)
    }

    private var currentTemperature: Double? {
        isManualEntryEnabled ? Self.validatedTemperature(temperature) : automaticTemperature
    }

    private var currentHumidity: Double? {
        isManualEntryEnabled ? Self.validatedHumidity(humidity) : automaticHumidity
    }

    private var currentDraft: HGRecordDraft? {
        let values: (temperature: Double, humidity: Double?)
        if isManualEntryEnabled {
            guard let validated = HGPhotoWeatherInput.validatedTemperatureAndOptionalHumidity(
                temperature: temperature,
                humidity: humidity
            ) else { return nil }
            values = validated
        } else {
            guard let automaticTemperature else { return nil }
            values = (automaticTemperature, automaticHumidity)
        }

        return HGRecordDraft(
            type: .thermometer,
            memo: "",
            temperature: values.temperature,
            humidity: values.humidity,
            teamName: teamName,
            workplace: workplace,
            siteName: siteName
        )
    }

    private var validationMessageForCurrentInput: String {
        if isManualEntryEnabled {
            let temperatureText = temperature.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Double(temperatureText), value.isFinite, (-50...60).contains(value) else {
                return "온도를 -50~60°C 범위의 숫자로 입력해주세요."
            }
            let humidityText = humidity.trimmingCharacters(in: .whitespacesAndNewlines)
            if !humidityText.isEmpty,
               let humidityValue = Double(humidityText), humidityValue.isFinite, !(0...100).contains(humidityValue) {
                return "습도는 0~100% 범위로 입력해주세요."
            } else if !humidityText.isEmpty, Double(humidityText) == nil {
                return "습도는 0~100% 범위의 숫자로 입력해주세요."
            }
        }
        return "온도를 확인해주세요. 자동 측정값이 없으면 직접 입력을 켜고 온도를 입력해주세요."
    }

    private func saveRecord() {
        UIApplication.shared.dismissKeyboard()
        guard let draft = currentDraft else {
            validationMessage = validationMessageForCurrentInput
            return
        }

        isSaving = true
        Task {
            defer { isSaving = false }
            switch await HGPhotoRecordSaveAction.perform(draft: draft, images: []) {
            case .photoRequired:
                return
            case let .success(result):
                onSave(result)
            case let .failure(failure):
                onFailure(failure, draft, [])
            }
        }
    }

    private static func validatedTemperature(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (-50...60).contains(value) else { return nil }
        return value
    }

    private static func validatedTemperature(_ text: String) -> Double? {
        validatedTemperature(Double(text.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    private static func validatedHumidity(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...100).contains(value) else { return nil }
        return value
    }

    private static func validatedHumidity(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return validatedHumidity(Double(trimmed))
    }

    private var validationAlert: Binding<Bool> { Binding(get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } }) }

}

#Preview {
    NavigationStack {
        ThermometerRecordView()
    }
}
