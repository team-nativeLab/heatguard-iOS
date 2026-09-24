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

    /// 숫자 키보드처럼 Return 키가 없는 입력 방식에 완료 버튼을 제공합니다.
    func keyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    UIApplication.shared.dismissKeyboard()
                }
            }
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
