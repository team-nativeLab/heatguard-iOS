//
//  WorkPhotoView.swift
//  heatguard-iOS
//

import SwiftUI

struct WorkPhotoView: View {
    @State private var memo: String
    @State private var photos: [UIImage]
    @State private var temperature: String
    @State private var humidity: String
    @State private var isSaving = false
    @State private var validationMessage: String?
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void
    let onPhotoRequired: (HGRecordDraft) -> Void
    let onMenuTap: () -> Void
    let onNotificationsTap: () -> Void
    let notificationCount: Int
    private let teamName: String?
    private let workplace: String?
    private let siteName: String?
    private let needsWeatherInput: Bool

    init(
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in },
        onPhotoRequired: @escaping (HGRecordDraft) -> Void = { _ in },
        initialMemo: String = "",
        initialPhotos: [UIImage] = [],
        initialTemperature: Double? = nil,
        initialHumidity: Double? = nil,
        weather: HomeWeather? = nil,
        teamName: String? = nil,
        workplace: String? = nil,
        siteName: String? = nil,
        onMenuTap: @escaping () -> Void = {},
        onNotificationsTap: @escaping () -> Void = {},
        notificationCount: Int = 0
    ) {
        self.onSave = onSave
        self.onFailure = onFailure
        self.onPhotoRequired = onPhotoRequired
        self.onMenuTap = onMenuTap
        self.onNotificationsTap = onNotificationsTap
        self.notificationCount = notificationCount
        self.teamName = teamName
        self.workplace = workplace
        self.siteName = siteName
        self.needsWeatherInput = weather?.temperature == nil || weather?.humidity == nil
        _memo = State(initialValue: initialMemo)
        _photos = State(initialValue: initialPhotos)
        _temperature = State(initialValue: (initialTemperature ?? weather?.temperature).map { String($0) } ?? "")
        _humidity = State(initialValue: (initialHumidity ?? weather?.humidity).map { String($0) } ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView { formContent }
                .scrollIndicators(.hidden)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
        .padding(.top, HGLayout.screenTopPadding)
        .background(HGColor.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HGPrimaryButton(
                title: isSaving ? "저장 중..." : "기록 저장",
                isEnabled: !isSaving,
                height: HGLayout.primaryButtonHeight,
                action: saveRecord
            )
            .padding(.horizontal, HGLayout.screenHorizontalPadding + 4)
            .padding(.vertical, 8)
            .background(HGColor.appBackground)
        }
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardOnBackgroundTap()
        .alert("온도·습도를 확인해주세요", isPresented: validationAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("작업 전 · 중 사진")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)

            Text("작업 현장과 보호조치를 확인 할 수 있는\n사진을 촬영해 주세요")
                .font(HGFont.regular(14, relativeTo: .subheadline))
                .foregroundStyle(HGColor.primaryText)
                .padding(.top, 10)

            HGPhotoCaptureSection(images: $photos)
                .padding(.top, 15)

            memoSection
                .padding(.top, 25)
            if needsWeatherInput {
                HGPhotoWeatherInput(temperature: $temperature, humidity: $humidity)
                    .padding(.top, 25)
            }
        }
        .padding(.top, HGLayout.screenContentTopPadding)
        .padding(.bottom, needsWeatherInput ? 16 : 0)
    }

    private var header: some View {
        HGScreenHeader(onMenuTap: onMenuTap, notificationCount: notificationCount, onNotificationsTap: onNotificationsTap)
    }

    private var memoSection: some View {
        HGOptionalMemoSection(
            placeholder: "작업 전 · 중 특이사항이 있다면 입력해주세요",
            height: 114,
            text: $memo
        )
        .padding(.horizontal, 7)
    }

    private func saveRecord() {
        UIApplication.shared.dismissKeyboard()
        guard let values = HGPhotoWeatherInput.validatedValues(temperature: temperature, humidity: humidity) else {
            validationMessage = "온도는 -50~60°C, 습도는 0~100% 범위의 숫자로 입력해주세요."
            return
        }
        let draft = HGRecordDraft(
            type: .work, memo: memo,
            temperature: values.temperature, humidity: values.humidity,
            teamName: teamName, workplace: workplace, siteName: siteName
        )
        isSaving = true
        Task {
            defer { isSaving = false }
            switch await HGPhotoRecordSaveAction.perform(draft: draft, images: photos) {
            case .photoRequired:
                onPhotoRequired(draft)
            case let .success(result):
                onSave(result)
            case let .failure(failure):
                onFailure(failure, draft, photos)
            }
        }
    }

    private var validationAlert: Binding<Bool> {
        Binding(get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } })
    }

}

#Preview {
    NavigationStack {
        WorkPhotoView()
    }
}
