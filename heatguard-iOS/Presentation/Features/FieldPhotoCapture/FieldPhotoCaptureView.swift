import SwiftUI

struct FieldPhotoCaptureView: View {
    @State private var photos: [UIImage]
    @State private var isPhotoSelectorPresented = false
    @State private var isSaving = false
    @State private var temperature: String
    @State private var humidity: String
    @State private var showInvalidMeasurement = false
    let draft: HGRecordDraft
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void
    let onPhotoRequired: (HGRecordDraft) -> Void
    let onNotificationsTap: () -> Void
    let notificationCount: Int

    init(
        draft: HGRecordDraft = HGRecordDraft(type: .thermometer, memo: ""),
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in },
        onPhotoRequired: @escaping (HGRecordDraft) -> Void = { _ in },
        initialPhotos: [UIImage] = [],
        onNotificationsTap: @escaping () -> Void = {},
        notificationCount: Int = 0
    ) {
        self.draft = draft
        self.onSave = onSave
        self.onFailure = onFailure
        self.onPhotoRequired = onPhotoRequired
        self.onNotificationsTap = onNotificationsTap
        self.notificationCount = notificationCount
        _photos = State(initialValue: initialPhotos)
        _temperature = State(initialValue: draft.temperature.map { String($0) } ?? "")
        _humidity = State(initialValue: draft.humidity.map { String($0) } ?? "")
    }

    var body: some View {
        HGFixedContent(keyboardAware: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text("현장 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .padding(.leading, 8)
                    .foregroundStyle(HGColor.primaryText)

                Text("온도계 데이터를 입력하고 현장 사진을\n촬영해 주세요.")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.leading, 8)
                    .padding(.top, 10)

                photoPreview(height: 290)
                    .padding(.top, 35)

                Text("온도계 데이터 입력")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .padding(.leading, 8)
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.top, 28)

                measurementCard
                    .padding(.top, 11)

                Text("다시하기")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .padding(.leading, 8)
                    .foregroundStyle(HGColor.primaryText)
                    .padding(.top, 17)

                photoSelector
                    .padding(.top, 15)
            }
            .padding(.top, HGLayout.screenContentTopPadding)
        }
        .padding(.horizontal, 38)
        .padding(.top, 8)
        .background(HGColor.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HGPrimaryButton(
                title: isSaving ? "저장 중..." : "저장",
                isEnabled: !photos.isEmpty && !isSaving,
                isLoading: isSaving,
                action: saveRecord
            )
                .padding(.horizontal, HGLayout.screenHorizontalPadding + 4)
                .padding(.vertical, 8)
                .background(HGColor.appBackground)
                .opacity(isPhotoSelectorPresented ? 0 : 1)
                .allowsHitTesting(!isPhotoSelectorPresented)
        }
        .hgRouteNavigationHeader(notificationCount: notificationCount, onNotificationsTap: onNotificationsTap)
        .alert("입력값을 확인해주세요", isPresented: $showInvalidMeasurement) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("온도는 -50~60°C, 습도는 0~100% 범위의 숫자로 입력해주세요.")
        }
    }

    private func photoPreview(height: CGFloat) -> some View {
        Group {
            if photos.isEmpty {
                RoundedRectangle(cornerRadius: 25)
                    .fill(HGColor.photoSelectionBackground)
                    .accessibilityLabel("현장 사진 미리보기")
            } else {
                TabView {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                            .clipped()
                            .accessibilityLabel("현장 사진 \(index + 1) / \(photos.count)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }

    private var measurementCard: some View {
        VStack(spacing: 0) {
            measurementInput(title: "온도 ( ℃ )", text: $temperature, color: HGColor.primaryText)
            measurementInput(title: "습도 ( % )", text: $humidity, color: HGColor.secondaryText)
            FieldMeasurementRow(measurement: FieldMeasurement(
                title: "체감온도 ( ℃ )",
                value: apparentTemperature.map { formattedMeasurement($0) } ?? "자동 계산"
            ), showDivider: false)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
    }

    private var photoSelector: some View {
        HGCompactPhotoSelector(images: $photos) { isPresented in
            isPhotoSelectorPresented = isPresented
        }
        .disabled(isSaving)
    }

    private func measurementInput(title: String, text: Binding<String>, color: Color) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .frame(width: 91, alignment: .leading)
            TextField("입력", text: text)
                .keyboardType(.decimalPad)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(color)
                .padding(.leading, 9)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HGColor.inputBorder).frame(height: 1)
                }
        }
        .frame(height: 32)
    }

    private var apparentTemperature: Double? {
        guard let values = HGPhotoWeatherInput.validatedValues(temperature: temperature, humidity: humidity) else {
            return nil
        }
        return HGWeatherMeasurement(temperature: values.temperature, humidity: values.humidity)?.apparentTemperature
    }

    private func formattedMeasurement(_ value: Double?) -> String {
        guard let value else { return "정보 없음" }
        return value.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    private func saveRecord() {
        guard let values = HGPhotoWeatherInput.validatedValues(temperature: temperature, humidity: humidity) else {
            showInvalidMeasurement = true
            return
        }
        let updatedDraft = HGRecordDraft(
            type: draft.type, memo: draft.memo, measuredAt: draft.measuredAt,
            temperature: values.temperature, humidity: values.humidity,
            restStartedAt: draft.restStartedAt, restEndedAt: draft.restEndedAt, restMinutes: draft.restMinutes,
            teamName: draft.teamName, workplace: draft.workplace, siteName: draft.siteName
        )
        isSaving = true
        Task {
            defer { isSaving = false }
            switch await HGPhotoRecordSaveAction.perform(draft: updatedDraft, images: photos) {
            case .photoRequired:
                onPhotoRequired(updatedDraft)
            case let .success(result):
                onSave(result)
            case let .failure(failure):
                onFailure(failure, updatedDraft, photos)
            }
        }
    }
}

private struct FieldMeasurement: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

private struct FieldMeasurementRow: View {
    let measurement: FieldMeasurement
    let showDivider: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(measurement.title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .frame(width: 91, alignment: .leading)

            Text(measurement.value)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(measurement.title.hasPrefix("온도") ? HGColor.primaryText : HGColor.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, showDivider ? 9 : 44)
                .overlay(alignment: .bottom) {
                    if showDivider {
                        Rectangle()
                            .fill(HGColor.inputBorder)
                            .frame(height: 1)
                    }
                }
        }
        .frame(height: 32)
    }
}

#Preview {
    NavigationStack {
        FieldPhotoCaptureView()
    }
}
