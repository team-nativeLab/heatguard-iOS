import SwiftUI

enum RecordType: CaseIterable, Identifiable {
    case thermometer
    case workPhoto
    case restPhoto

    var id: Self { self }

    var title: String {
        switch self {
        case .thermometer: "온도계 사진"
        case .workPhoto: "작업 사진"
        case .restPhoto: "휴식 사진"
        }
    }

    var description: String {
        switch self {
        case .thermometer: "온도/습도 입력 후 체감온도 계산"
        case .workPhoto: "작업 중 사진을 1~2장 업로드"
        case .restPhoto: "휴식 중 사진을 1~2장 업로드"
        }
    }

    var imageName: String {
        switch self {
        case .thermometer: "ThermometerIllustration"
        case .workPhoto: "WorkPhoto"
        case .restPhoto: "RestPhoto"
        }
    }
}

struct RecordTypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: RecordType?

    let onConfirm: (RecordType) -> Void

    init(onConfirm: @escaping (RecordType) -> Void = { _ in }) {
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("기록 유형을 선택하세요")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
                .padding(.top, 18)

            VStack(spacing: 9) {
                ForEach(RecordType.allCases) { type in
                    RecordTypeCard(type: type, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            .padding(.top, 33)
            .padding(.horizontal, HGLayout.screenHorizontalPadding)
            Spacer(minLength: 16)
            HGPrimaryButton(title: "확인", isEnabled: selectedType != nil) {
                guard let selectedType else { return }
                dismiss()
                onConfirm(selectedType)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HGColor.popupBackground)
        .presentationBackground(HGColor.popupBackground)
        .presentationDetents([.height(639)])
        .presentationCornerRadius(40)
        .presentationDragIndicator(.hidden)
    }
}

private struct RecordTypeCard: View {
    let type: RecordType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 33) {
                illustration

                VStack(alignment: .leading, spacing: 13) {
                    Text(type.title)
                        .font(HGFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(HGColor.primaryText)

                    Text(type.description)
                        .font(HGFont.semiBold(14, relativeTo: .subheadline))
                        .foregroundStyle(HGColor.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 35)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, minHeight: 143, alignment: .leading)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 25))
            .overlay {
                RoundedRectangle(cornerRadius: 25)
                    .stroke(isSelected ? HGColor.primary : HGColor.inputBorder, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.title)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }

    private var illustration: some View {
        // Figma uses a 109pt thermometer canvas centered on the same 47pt icon column.
        // Keep the canvas outside the layout width so all three text columns align.
        Color.clear
            .frame(width: 47, height: 47)
            .overlay {
                Image(type.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: type == .thermometer ? 109 : 47,
                           height: type == .thermometer ? 109 : 47)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    RecordTypeSelectionView()
}
