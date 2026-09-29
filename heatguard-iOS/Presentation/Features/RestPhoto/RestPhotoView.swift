import SwiftUI

struct RestPhotoView: View {
    @State private var memo: String
    @State private var photos: [UIImage]
    @State private var restStartedAt = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: .now) ?? .now
    @State private var restEndedAt = Calendar.current.date(bySettingHour: 13, minute: 30, second: 0, of: .now) ?? .now
    @State private var isSaving = false
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void
    let onPhotoRequired: (HGRecordDraft) -> Void
    let onMenuTap: () -> Void

    init(
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in },
        onPhotoRequired: @escaping (HGRecordDraft) -> Void = { _ in },
        initialMemo: String = "",
        initialPhotos: [UIImage] = [],
        initialRestStartedAt: Date? = nil,
        initialRestEndedAt: Date? = nil,
        onMenuTap: @escaping () -> Void = {}
    ) {
        self.onSave = onSave
        self.onFailure = onFailure
        self.onPhotoRequired = onPhotoRequired
        self.onMenuTap = onMenuTap
        _memo = State(initialValue: initialMemo)
        _photos = State(initialValue: initialPhotos)
        _restStartedAt = State(initialValue: initialRestStartedAt ?? Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: .now) ?? .now)
        _restEndedAt = State(initialValue: initialRestEndedAt ?? Calendar.current.date(bySettingHour: 13, minute: 30, second: 0, of: .now) ?? .now)
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
                isEnabled: !isSaving && isRestPeriodValid,
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
        HGScreenHeader(onMenuTap: onMenuTap)
    }

    private var restForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("휴식 시간").font(HGFont.semiBold(16))
            HStack(spacing: 8) {
                DatePicker("휴식 시작 시간", selection: $restStartedAt, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .accessibilityLabel("휴식 시작 시간")
                Text("~")
                    .font(HGFont.regular(13, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                DatePicker("휴식 종료 시간", selection: $restEndedAt, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .accessibilityLabel("휴식 종료 시간")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
            .padding(.horizontal, 12)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.inputCardCornerRadius))
            .overlay { RoundedRectangle(cornerRadius: HGLayout.inputCardCornerRadius).stroke(isRestPeriodValid ? HGColor.inputBorder : HGColor.error, lineWidth: 1) }
            .padding(.top, 12)
            if !isRestPeriodValid {
                Text("종료 시간은 시작 시간 이후로 설정해주세요")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.error)
                    .padding(.top, 8)
            }
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
        let draft = HGRecordDraft(
            type: .rest,
            memo: memo,
            restStartedAt: restStartedAt,
            restEndedAt: restEndedAt
        )
        isSaving = true
        Task {
            defer { isSaving = false }
            switch await HGPhotoRecordSaveAction.perform(draft: draft, images: photos) {
            case .photoRequired:
                onPhotoRequired(draft)
            case let .success(result):
                onSave(result)
            case let .failure(failure):
                onFailure(failure, draft, photos)
            }
        }
    }

    private var isRestPeriodValid: Bool { restEndedAt > restStartedAt }

}

#Preview { NavigationStack { RestPhotoView() } }
