import SwiftUI

/// 고정 화면의 콘텐츠 비율을 유지하며 사용 가능한 높이에 맞춥니다.
/// 버튼은 이 영역 바깥의 safeAreaInset에 두어 위치와 터치 크기를 유지합니다.
struct HGFixedContent<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let scale = Self.scale(contentHeight: contentHeight, availableHeight: geometry.size.height)
            content
                .frame(width: geometry.size.width / max(scale, 0.01))
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { contentGeometry in
                        Color.clear.preference(key: HGContentHeightKey.self, value: contentGeometry.size.height)
                    }
                }
                .scaleEffect(scale, anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .onPreferenceChange(HGContentHeightKey.self) { contentHeight = $0 }
        }
    }

    static func scale(contentHeight: CGFloat, availableHeight: CGFloat) -> CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(1, max(0, availableHeight) / contentHeight)
    }
}

private struct HGContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
