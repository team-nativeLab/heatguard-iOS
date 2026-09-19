import SwiftUI

/// 사진 기록 화면에서 공통으로 사용하는 선택 메모 입력 영역입니다.
struct HGOptionalMemoSection: View {
    private let title: String
    private let placeholder: String
    private let height: CGFloat
    @Binding private var text: String

    init(
        title: String = "메모",
        placeholder: String,
        height: CGFloat,
        text: Binding<String>
    ) {
        self.title = title
        self.placeholder = placeholder
        self.height = height
        _text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(HGFont.semiBold(16, relativeTo: .body))
                    .foregroundStyle(HGColor.primaryText)

                Text("(선택)")
                    .font(HGFont.medium(13, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
            }

            TextEditor(text: $text)
                .font(HGFont.medium(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(height: height)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(HGFont.medium(13, relativeTo: .caption))
                            .foregroundStyle(HGColor.secondaryText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HGColor.inputBorder, lineWidth: 1)
                }
        }
    }
}

#Preview {
    HGOptionalMemoSection(
        placeholder: "특이사항이 있다면 입력해주세요",
        height: 114,
        text: .constant("")
    )
    .padding()
    .background(HGColor.appBackground)
}
