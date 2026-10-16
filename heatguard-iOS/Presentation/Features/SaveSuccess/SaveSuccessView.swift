import SwiftUI

struct SaveSuccessView: View {
    let result: HGRecordSaveResult
    let onConfirm: () -> Void

    init(result: HGRecordSaveResult, onConfirm: @escaping () -> Void = {}) {
        self.result = result
        self.onConfirm = onConfirm
    }

    var body: some View {
        HGStatusPopup(title: "기록 저장") {
            successCard.padding(.top, 52)
            summaryCard.padding(.top, 26)
        } actions: {
            HGPrimaryButton(title: "확인", action: onConfirm)
                .padding(.horizontal, 28)
        }
    }

    private var successCard: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(HGColor.successBackground)
                    .frame(width: 84, height: 84)

                Image("SaveSuccessCheck")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 53, height: 53)
            }

            Text("기록이 저장됐어요")
                .font(HGFont.bold(20, relativeTo: .title2))
                .padding(.top, 34)

            Text(photoStatusMessage)
                .font(HGFont.semiBold(15))
                .foregroundStyle(HGColor.secondaryText)
                .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, minHeight: 178)
        .padding(HGLayout.cardPadding)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.popupCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HGLayout.popupCornerRadius)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("저장한 기록 요약")
                .font(HGFont.bold(15))
                .padding(.bottom, 12)

            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                SavedRecordRow(record: record)

                if index < records.count - 1 {
                    Divider()
                }
            }
        }
        .padding(HGLayout.cardPadding)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: HGLayout.popupCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HGLayout.popupCornerRadius)
                .stroke(HGColor.inputBorder, lineWidth: 1)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
    }

    private var records: [SavedRecord] {
        [
            SavedRecord(title: result.draft.type.savedRecordTitle, detail: recordDetail),
            SavedRecord(title: "첨부 사진", detail: photoSummary),
            SavedRecord(title: "저장 시간", detail: HGDateFormatting.timestamp(result.savedAt))
        ]
    }

    private var recordDetail: String {
        guard result.draft.type == .thermometer else { return "사진과 메모가 저장됐어요" }

        let temperature = result.draft.temperature.map { String(format: "%.1f ℃", $0) } ?? "온도 정보 없음"
        let humidity = result.draft.humidity.map { String(format: "습도 %.0f%%", $0) } ?? "습도 정보 없음"
        return "\(temperature) · \(humidity)"
    }

    private var photoStatusMessage: String {
        switch result.photoVerification {
        case let .checked(count) where count == result.expectedPhotoCount:
            "기록에 사진 \(count)장이 연결됐어요."
        case .checked:
            "기록은 저장됐지만 일부 사진 연결을 확인하지 못했어요. 기록 상세를 확인해주세요."
        case .unavailable:
            "기록은 저장됐지만 사진 연결을 확인하지 못했어요. 기록 상세를 확인해주세요."
        }
    }

    private var photoSummary: String {
        switch result.photoVerification {
        case let .checked(count): "\(count)/\(result.expectedPhotoCount)장 연결 확인"
        case .unavailable: "사진 연결 확인 필요"
        }
    }
}

private struct SavedRecord: Identifiable {
    let title: String
    let detail: String

    var id: String { title }
}

private struct SavedRecordRow: View {
    let record: SavedRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(HGFont.bold(14))

                Text(record.detail)
                    .font(HGFont.semiBold(12))
                    .foregroundStyle(HGColor.secondaryText)
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    SaveSuccessView(
        result: HGRecordSaveResult(
            recordID: "preview",
            draft: HGRecordDraft(type: .thermometer, memo: "", temperature: 47.5, humidity: 55),
            expectedPhotoCount: 2,
            photoVerification: .checked(photoURLCount: 2),
            savedAt: .now
        )
    )
}
