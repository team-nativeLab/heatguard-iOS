import SwiftUI

struct SaveBeforeConfirmationView: View {
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
    }

    private var header: some View {
        HGScreenHeader()
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
        HGCompactPhotoSelector()
    }
}

private struct DisabledManualInputCard: View {
    var body: some View {
        HGManualInputCard(isEnabled: .constant(false), isLocked: true)
    }
}

#Preview {
    NavigationStack {
        SaveBeforeConfirmationView()
    }
}
