import SwiftUI

struct FieldPhotoCaptureView: View {
    @State private var showsPhotoSelection = false

    let onSave: () -> Void

    private let measurements = [
        FieldMeasurement(title: "온도 ( ℃ )", value: "47.5"),
        FieldMeasurement(title: "습도 ( % )", value: "55"),
        FieldMeasurement(title: "체감온도 ( ℃ )", value: "자동 계산")
    ]

    init(onSave: @escaping () -> Void = {}) {
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

            HGPrimaryButton(title: "저장", height: 48, action: onSave)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsPhotoSelection) {
            HGPhotoCaptureSection()
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack {
            Button(action: {}) {
                Image("menu")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("폭염가드")
                .font(HGFont.bold(20, relativeTo: .title2))

            Spacer()

            Button(action: {}) {
                Image("bell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
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
        Button {
            showsPhotoSelection = true
        } label: {
            HStack(spacing: 0) {
                Image("camera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .padding(.leading, 19)

                Spacer()

                Text("사진 촬영 또는\n앨범에서 선택")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
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
