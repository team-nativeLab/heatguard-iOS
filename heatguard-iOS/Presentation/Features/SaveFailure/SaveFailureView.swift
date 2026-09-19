import SwiftUI

struct SaveFailureView: View {
    private let error = (title: "서버와 연결할 수 없습니다", message: "잠시 후 다시 시도해주세요")
    let onRetry: () -> Void
    let onTemporarySave: () -> Void

    init(
        onRetry: @escaping () -> Void = {},
        onTemporarySave: @escaping () -> Void = {}
    ) {
        self.onRetry = onRetry
        self.onTemporarySave = onTemporarySave
    }

    var body: some View {
        HGStatusPopup(title: "기록 저장") {
            statusCard.padding(.top, 52)
            HGPopupCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("오류 내용")
                        .font(HGFont.bold(15))
                    Text("\(error.title)\n\(error.message)")
                        .font(HGFont.medium(15))
                        .foregroundStyle(HGColor.secondaryText)
                        .lineSpacing(8)
                }
                .frame(maxWidth: .infinity, minHeight: 83, alignment: .leading)
            }
            .padding(.horizontal, 25)
            .padding(.top, 26)
        } actions: {
            VStack(spacing: 14) {
                HGPrimaryButton(title: "다시 시도하기", action: onRetry)
                HGSecondaryButton(title: "임시저장 후 나가기", action: onTemporarySave)
            }
            .padding(.horizontal, 28)
        }
    }

    private var statusCard: some View {
        HGPopupCard {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 84, height: 84)

                    Image("Warning")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 59, height: 59)
                }
                Text("기록이 저장하지 못했어요")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .padding(.top, 34)
                Text("네트워크 연결을 확인한 후 다시시도 해주세요")
                    .font(HGFont.semiBold(15))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.top, 15)
            }
            .frame(maxWidth: .infinity, minHeight: 178)
        }
        .padding(.horizontal, 25)
    }
}
