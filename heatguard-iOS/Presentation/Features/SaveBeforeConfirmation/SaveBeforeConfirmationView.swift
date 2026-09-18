import SwiftUI

struct SaveBeforeConfirmationView: View {
    @State private var showsPhotoSelection = false

    let onRetry: () -> Void
    let onSave: () -> Void

    init(onRetry: @escaping () -> Void = {}, onSave: @escaping () -> Void = {}) {
        self.onRetry = onRetry
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 0) {
                    Text("현장 사진")
                        .font(HGFont.bold(20, relativeTo: .title2))

                    Text("온도계 데이터를 입력하고 현장 사진을\n촬영해 주세요.")
                        .font(HGFont.regular(14, relativeTo: .subheadline))
                        .padding(.top, 10)

                    missingPhotoNotice
                        .padding(.top, 35)

                    DisabledManualInputCard()
                        .padding(.top, 20)

                    Button("다시하기", action: onRetry)
                        .font(HGFont.bold(20, relativeTo: .title2))
                        .buttonStyle(.plain)
                        .padding(.top, 17)

                    photoSelector
                        .padding(.top, 15)
                }
                .padding(.top, 45)

                HGPrimaryButton(title: "저장", height: 48, action: onSave)
                    .padding(.top, 46)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 25)
            .padding(.top, 24)
        }
        .scrollIndicators(.hidden)
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

    private var missingPhotoNotice: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(HGColor.fieldBackground)

            VStack(spacing: 18) {
                Image("CloseCircle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)

                Text("온도계가 아직 저장이\n안되었어요")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 290)
        .accessibilityLabel("온도계가 아직 저장되지 않았습니다")
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

private struct DisabledManualInputCard: View {
    private let fields = [
        ManualInputField(title: "온도 (°C)", value: "예: 47.5"),
        ManualInputField(title: "습도 (%)", value: "예: 55"),
        ManualInputField(title: "체감온도 (°C)", value: "자동 계산")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("온도계 데이터 직접 입력")
                    .font(HGFont.bold(15, relativeTo: .subheadline))

                Spacer()

                Toggle("온도계 데이터 직접 입력", isOn: .constant(false))
                    .labelsHidden()
                    .disabled(true)
            }

            HStack(spacing: 8) {
                ForEach(fields) { field in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(field.title)
                            .font(HGFont.medium(11, relativeTo: .caption2))
                        Text(field.value)
                            .font(HGFont.regular(13, relativeTo: .caption))
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                            .padding(.horizontal, 10)
                            .background(HGColor.metricBackground, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 16)

            Text("저장이 확정되면 수정할 수 없습니다.")
                .font(HGFont.regular(11, relativeTo: .caption2))
                .padding(.top, 18)
        }
        .foregroundStyle(HGColor.secondaryText)
        .padding(20)
        .opacity(0.5)
        .background(HGColor.metricBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
    }
}

private struct ManualInputField: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

#Preview {
    NavigationStack {
        SaveBeforeConfirmationView()
    }
}
