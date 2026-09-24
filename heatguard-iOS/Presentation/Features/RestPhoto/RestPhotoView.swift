import SwiftUI

struct RestPhotoView: View {
    private let restPeriod = "13 : 00 ~ 13 : 30 (중간 휴식)"

    @State private var memo: String
    @State private var photos: [UIImage]
    @State private var isSaving = false
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void
    let onPhotoRequired: (HGRecordDraft) -> Void

    init(
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in },
        onPhotoRequired: @escaping (HGRecordDraft) -> Void = { _ in },
        initialMemo: String = "",
        initialPhotos: [UIImage] = []
    ) {
        self.onSave = onSave
        self.onFailure = onFailure
        self.onPhotoRequired = onPhotoRequired
        _memo = State(initialValue: initialMemo)
        _photos = State(initialValue: initialPhotos)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("휴식시간 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))

                Text("휴식시간과 휴식 환경을 기록해주세요")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .padding(.top, 10)

                HGPhotoCaptureSection(images: $photos)
                    .padding(.top, 34)

                restForm
                    .padding(.top, 26)
            }
            .padding(.top, HGLayout.screenContentTopPadding)

            Spacer(minLength: 0)

            HGPrimaryButton(
                title: isSaving ? "저장 중..." : "기록 저장",
                isEnabled: !isSaving,
                height: HGLayout.primaryButtonHeight,
                action: saveRecord
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
        .padding(.top, HGLayout.screenTopPadding)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardOnBackgroundTap()
    }

    private var header: some View {
        HGScreenHeader()
    }

    private var restForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("휴식 시간").font(HGFont.semiBold(16))
            Text(restPeriod)
                .font(HGFont.bold(13, relativeTo: .caption))
                .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
                .padding(.horizontal, 15)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.inputCardCornerRadius))
                .overlay { RoundedRectangle(cornerRadius: HGLayout.inputCardCornerRadius).stroke(HGColor.inputBorder, lineWidth: 1) }
                .padding(.top, 12)
            HGOptionalMemoSection(
                placeholder: "휴식 관련 메모를 입력해주세요",
                height: 74,
                text: $memo
            )
            .padding(.top, 25)
        }
        .padding(.horizontal, 7)
    }

    private func saveRecord() {
        UIApplication.shared.dismissKeyboard()
        let draft = HGRecordDraft(type: .rest, memo: memo)
        guard !photos.isEmpty else {
            onPhotoRequired(draft)
            return
        }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let result = try await HGRecordUploadService().save(
                    draft,
                    images: photos
                )
                onSave(result)
            } catch {
                onFailure(HGRecordSaveFailure(error: error), draft, photos)
            }
        }
    }

}

#Preview { NavigationStack { RestPhotoView() } }
