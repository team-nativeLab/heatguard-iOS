import SwiftUI

struct FieldPhotoCaptureView: View {
    @State private var photos: [UIImage] = []
    @State private var isSaving = false
    @State private var saveError: String?
    let draft: HGRecordDraft
    let onSave: () -> Void

    private let measurements = [
        FieldMeasurement(title: "온도 ( ℃ )", value: "47.5"),
        FieldMeasurement(title: "습도 ( % )", value: "55"),
        FieldMeasurement(title: "체감온도 ( ℃ )", value: "자동 계산")
    ]

    init(draft: HGRecordDraft = HGRecordDraft(type: .thermometer, memo: ""), onSave: @escaping () -> Void = {}) {
        self.draft = draft
        self.onSave = onSave
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
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(title: isSaving ? "저장 중..." : "저장", isEnabled: !isSaving, height: 48, action: saveRecord)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .alert("기록을 저장하지 못했습니다.", isPresented: saveErrorAlert) { Button("확인", role: .cancel) {} } message: { Text(saveError ?? "") }
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

    private var saveErrorAlert: Binding<Bool> { Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } }) }

    private func saveRecord() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do { try await HGRecordUploadService().save(draft, images: photos); onSave() }
            catch { saveError = error.localizedDescription }
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
        .padding(.horizontal, 20)
        .frame(height: 36)
    }
}

#Preview {
    NavigationStack {
        FieldPhotoCaptureView()
    }
}
