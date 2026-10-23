import SwiftUI
import UIKit

/// 고정 화면의 콘텐츠 비율을 유지하며 사용 가능한 높이에 맞춥니다.
/// 버튼은 이 영역 바깥의 safeAreaInset에 두어 위치와 터치 크기를 유지합니다.
struct HGFixedContent<Content: View>: View {
    private let content: (Bool) -> Content
    private let compactHeightThreshold: CGFloat?
    private let keyboardAware: Bool
    @State private var contentHeight: CGFloat = 0
    @State private var isKeyboardVisible = false

    init(keyboardAware: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.compactHeightThreshold = nil
        self.keyboardAware = keyboardAware
        self.content = { _ in content() }
    }

    init(
        compactHeightThreshold: CGFloat,
        keyboardAware: Bool = false,
        @ViewBuilder content: @escaping (Bool) -> Content
    ) {
        self.compactHeightThreshold = compactHeightThreshold
        self.keyboardAware = keyboardAware
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = Self.scale(
                contentHeight: contentHeight,
                availableHeight: geometry.size.height,
                keyboardVisible: keyboardAware && isKeyboardVisible
            )
            let isCompact = compactHeightThreshold.map { geometry.size.height < $0 } ?? false
            Group {
                if keyboardAware {
                    ScrollView {
                        content(isCompact)
                            .frame(width: geometry.size.width / max(scale, 0.01))
                            .fixedSize(horizontal: false, vertical: true)
                            .background {
                                GeometryReader { contentGeometry in
                                    Color.clear.preference(key: HGContentHeightKey.self, value: contentGeometry.size.height)
                                }
                            }
                            .scaleEffect(scale, anchor: .top)
                            .frame(
                                width: geometry.size.width,
                                height: isKeyboardVisible ? nil : geometry.size.height,
                                alignment: .top
                            )
                    }
                    .scrollDisabled(!isKeyboardVisible)
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    content(isCompact)
                        .frame(width: geometry.size.width / max(scale, 0.01))
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            GeometryReader { contentGeometry in
                                Color.clear.preference(key: HGContentHeightKey.self, value: contentGeometry.size.height)
                            }
                        }
                        .scaleEffect(scale, anchor: .top)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                }
            }
            .onPreferenceChange(HGContentHeightKey.self) { contentHeight = $0 }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { UIApplication.shared.dismissKeyboard() }
            }
        }
    }

    static func scale(contentHeight: CGFloat, availableHeight: CGFloat, keyboardVisible: Bool = false) -> CGFloat {
        guard !keyboardVisible else { return 1 }
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
