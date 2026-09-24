//
//  WorkPhotoView.swift
//  heatguard-iOS
//

import SwiftUI

struct WorkPhotoView: View {
    @State private var memo = ""
    @State private var photos: [UIImage] = []
    @State private var isSaving = false
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (String) -> Void
    let onPhotoRequired: (HGRecordDraft) -> Void

    init(
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (String) -> Void = { _ in },
        onPhotoRequired: @escaping (HGRecordDraft) -> Void = { _ in }
    ) {
        self.onSave = onSave
        self.onFailure = onFailure
        self.onPhotoRequired = onPhotoRequired
    }

    var body: some View {
        VStack(spacing: 0) {
            header

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
        let draft = HGRecordDraft(type: .work, memo: memo)
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
                onFailure(error.localizedDescription)
            }
        }
    }

}

#Preview {
    NavigationStack {
        WorkPhotoView()
    }
}
