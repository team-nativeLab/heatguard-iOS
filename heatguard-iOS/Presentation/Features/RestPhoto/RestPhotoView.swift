import SwiftUI

struct RestPhotoView: View {
    private let restPeriod = "13 : 00 ~ 13 : 30 (중간 휴식)"

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

    private var restForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("휴식 시간").font(HGFont.semiBold(16))
            Text(restPeriod)
                .font(HGFont.bold(13, relativeTo: .caption))
                .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
                .padding(.horizontal, 15)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(HGColor.inputBorder, lineWidth: 1) }
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

    private var saveErrorAlert: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func saveRecord() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await HGRecordUploadService().save(
                    HGRecordDraft(type: .rest, memo: memo),
                    images: photos
                )
                onSave()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

}

#Preview { NavigationStack { RestPhotoView() } }
