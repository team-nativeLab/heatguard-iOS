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

            Text("현장관리자에게 실시간으로 전송됩니다.")
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
            SavedRecord(title: result.draft.type.savedRecordTitle, detail: recordDetail, isNavigable: true),
            SavedRecord(title: "첨부 사진", detail: "\(result.photoCount)장", isNavigable: true),
            SavedRecord(title: "저장 시간", detail: result.savedAt.formatted(date: .numeric, time: .shortened), isNavigable: false)
        ]
    }

    private var recordDetail: String {
        guard result.draft.type == .thermometer else { return "사진과 메모가 저장됐어요" }

        let temperature = result.draft.temperature.map { String(format: "%.1f ℃", $0) } ?? "온도 정보 없음"
        let humidity = result.draft.humidity.map { String(format: "습도 %.0f%%", $0) } ?? "습도 정보 없음"
        return "\(temperature) · \(humidity)"
    }
}

private struct SavedRecord: Identifiable {
    let title: String
    let detail: String
    let isNavigable: Bool

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

            if record.isNavigable {
                Image("ChevronRight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    SaveSuccessView(
        result: HGRecordSaveResult(
            recordID: "preview",
            draft: HGRecordDraft(type: .thermometer, memo: "", temperature: 47.5, humidity: 55),
            photoCount: 2,
            savedAt: .now
        )
    )
}
