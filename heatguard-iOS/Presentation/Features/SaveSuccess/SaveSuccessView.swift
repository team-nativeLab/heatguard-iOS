import SwiftUI

struct SaveSuccessView: View {
    private let records = [
        SavedRecord(title: "온도계 기록", detail: "47.5 ℃  ( 습도 55% 체감 40.7℃ )", isNavigable: true),
        SavedRecord(title: "작업 사진", detail: "2장", isNavigable: true),
        SavedRecord(title: "휴식 사진", detail: "2장", isNavigable: true),
        SavedRecord(title: "저장 시간", detail: "2026.07.18 10 : 30", isNavigable: false)
    ]
    let onConfirm: () -> Void

    init(onConfirm: @escaping () -> Void = {}) {
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

#Preview { SaveSuccessView() }
