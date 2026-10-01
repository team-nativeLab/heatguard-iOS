import SwiftUI
import UIKit

extension View {
    /// 화면의 입력 영역 밖을 탭했을 때 현재 활성화된 키보드를 닫습니다.
    func dismissKeyboardOnBackgroundTap() -> some View {
        contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.dismissKeyboard()
            }
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
