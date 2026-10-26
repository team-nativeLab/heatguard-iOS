import SwiftUI
import UIKit

extension View {
    /// 화면의 입력 영역 밖을 탭했을 때 현재 활성화된 키보드를 닫습니다.
    func dismissKeyboardOnBackgroundTap() -> some View {
        modifier(KeyboardDismissTapModifier())
    }
}

private struct KeyboardDismissTapModifier: ViewModifier {
    @State private var inputFrames: [CGRect] = []

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: HGKeyboardDismissTapConstants.coordinateSpace)
            .onPreferenceChange(HGKeyboardInputFramesPreferenceKey.self) { inputFrames = $0 }
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .named(HGKeyboardDismissTapConstants.coordinateSpace))
                    .onEnded { tap in
                        guard !inputFrames.contains(where: { $0.contains(tap.location) }) else { return }
                        UIApplication.shared.dismissKeyboard()
                    }
            )
    }
}

enum HGKeyboardDismissTapConstants {
    static let coordinateSpace = "HGKeyboardDismissTap"
}

struct HGKeyboardInputFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

extension UIApplication {
    func dismissKeyboard() {
        sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
