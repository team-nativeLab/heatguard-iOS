//
//  WorkPhotoView.swift
//  heatguard-iOS
//

import SwiftUI

struct WorkPhotoView: View {
    @State private var memo = ""
    @State private var photos: [UIImage] = []
    @State private var isSaving = false
    @State private var saveError: String?

    let onSave: () -> Void

    init(onSave: @escaping () -> Void = {}) {
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("작업 전 · 중 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(.black)

                Text("작업 현장과 보호조치를 확인 할 수 있는\n사진을 촬영해 주세요")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(.black)
                    .padding(.top, 10)

                HGPhotoCaptureSection(images: $photos)
                    .padding(.top, 15)

                memoSection
                    .padding(.top, 25)
            }
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(
                title: isSaving ? "저장 중..." : "기록 저장",
                isEnabled: !isSaving,
                height: 48,
                action: saveRecord
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .alert("기록을 저장하지 못했습니다.", isPresented: saveErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
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

    private var saveErrorAlert: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func saveRecord() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await HGRecordUploadService().save(
                    HGRecordDraft(type: .work, memo: memo),
                    images: photos
                )
                onSave()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

}

#Preview {
    NavigationStack {
        WorkPhotoView()
    }
}
