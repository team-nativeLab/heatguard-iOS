import SwiftUI

struct SaveBeforeConfirmationView: View {
    @State private var photos: [UIImage] = []
    @State private var isSaving = false

    let draft: HGRecordDraft
    let onRetry: () -> Void
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void

    init(
        draft: HGRecordDraft,
        onRetry: @escaping () -> Void = {},
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in }
    ) {
        self.draft = draft
        self.onRetry = onRetry
        self.onSave = onSave
        self.onFailure = onFailure
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

                    if draft.type == .thermometer {
                        DisabledManualInputCard()
                            .padding(.top, 20)
                    }

                    Button("다시하기", action: onRetry)
                        .font(HGFont.bold(20, relativeTo: .title2))
                        .buttonStyle(.plain)
                        .padding(.top, 17)

                    photoSelector
                        .padding(.top, 15)
                }
                .padding(.top, HGLayout.screenContentTopPadding)

                HGPrimaryButton(
                    title: isSaving ? "저장 중..." : "저장",
                    isEnabled: !photos.isEmpty && !isSaving,
                    action: saveRecord
                )
                    .padding(.top, 46)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, HGLayout.screenHorizontalPadding)
            .padding(.top, HGLayout.screenTopPadding)
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

                Text("현장 사진을\n추가해주세요")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 290)
        .accessibilityLabel("온도계가 아직 저장되지 않았습니다")
    }

    private var photoSelector: some View {
        HGCompactPhotoSelector(images: $photos)
    }

    private func saveRecord() {
        guard !photos.isEmpty else { return }

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

private struct DisabledManualInputCard: View {
    var body: some View {
        HGManualInputCard(isEnabled: .constant(false), isLocked: true)
    }
}

#Preview {
    NavigationStack {
        SaveBeforeConfirmationView(draft: HGRecordDraft(type: .thermometer, memo: ""))
    }
}
