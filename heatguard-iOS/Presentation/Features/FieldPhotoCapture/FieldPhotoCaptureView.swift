import SwiftUI

struct FieldPhotoCaptureView: View {
    @State private var photos: [UIImage]
    @State private var isSaving = false
    let draft: HGRecordDraft
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void
    let onPhotoRequired: (HGRecordDraft) -> Void

    init(
        draft: HGRecordDraft = HGRecordDraft(type: .thermometer, memo: ""),
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in },
        onPhotoRequired: @escaping (HGRecordDraft) -> Void = { _ in },
        initialPhotos: [UIImage] = []
    ) {
        self.draft = draft
        self.onSave = onSave
        self.onFailure = onFailure
        self.onPhotoRequired = onPhotoRequired
        _photos = State(initialValue: initialPhotos)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("현장 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))

                Text("온도계 데이터를 입력하고 현장 사진을\n촬영해 주세요.")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .padding(.top, 10)

                photoPreview
                    .padding(.top, 35)

                Text("온도계 데이터 입력")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .padding(.top, 28)

                measurementCard
                    .padding(.top, 11)

                Text("다시하기")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .padding(.top, 17)

                photoSelector
                    .padding(.top, 15)
            }
            .padding(.top, HGLayout.screenContentTopPadding)

            Spacer(minLength: 0)

            HGPrimaryButton(title: isSaving ? "저장 중..." : "저장", isEnabled: !isSaving, action: saveRecord)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
        .padding(.top, HGLayout.screenTopPadding)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HGScreenHeader()
    }

    private var photoPreview: some View {
        RoundedRectangle(cornerRadius: 25)
            .fill(HGColor.fieldBackground)
            .frame(maxWidth: .infinity, minHeight: 290)
            .accessibilityLabel("현장 사진 미리보기")
    }

    private var measurementCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(measurements.enumerated()), id: \.element.id) { index, measurement in
                FieldMeasurementRow(measurement: measurement)

                if index < measurements.count - 1 {
                    Divider()
                        .padding(.leading, 91)
                }
            }
        }
        .padding(.vertical, 9)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
    }

    private var photoSelector: some View {
        HGCompactPhotoSelector(images: $photos)
    }

    private var measurements: [FieldMeasurement] {
        [
            FieldMeasurement(title: "온도 ( ℃ )", value: formattedMeasurement(draft.temperature)),
            FieldMeasurement(title: "습도 ( % )", value: formattedMeasurement(draft.humidity)),
            FieldMeasurement(title: "체감온도 ( ℃ )", value: "자동 계산")
        ]
    }

    private func formattedMeasurement(_ value: Double?) -> String {
        guard let value else { return "정보 없음" }
        return value.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    private func saveRecord() {
        guard !photos.isEmpty else {
            onPhotoRequired(draft)
            return
        }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let result = try await HGRecordUploadService().save(draft, images: photos)
                onSave(result)
            } catch {
                onFailure(HGRecordSaveFailure(error: error), draft, photos)
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

    var body: some View {
        HStack(spacing: 0) {
            Text(measurement.title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .frame(width: 101, alignment: .leading)

            Text(measurement.value)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(measurement.value == "자동 계산" ? HGColor.secondaryText : HGColor.primaryText)
        }
            .padding(.horizontal, HGLayout.cardPadding)
        .frame(height: 36)
    }
}

#Preview {
    NavigationStack {
        FieldPhotoCaptureView()
    }
}
