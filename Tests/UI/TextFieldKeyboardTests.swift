import SwiftUI
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class TextFieldKeyboardTests: XCTestCase {
    func testNumericFieldsUseNumericKeyboards() {
        XCTAssertEqual(HGTextFieldInputType.number.keyboardType, .numberPad)
        XCTAssertEqual(HGTextFieldInputType.decimal.keyboardType, .decimalPad)
        XCTAssertEqual(HGTextFieldInputType.phone.keyboardType, .phonePad)
    }

    func testOneTimeCodeFieldBecomesFirstResponderWhenAttachedToWindow() async {
        let editingBegan = expectation(forNotification: UITextField.textDidBeginEditingNotification, object: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            XCTFail("The test needs an active window scene.")
            return
        }
        let hostingController = UIHostingController(
            rootView: HGOneTimeCodeTextField(
                text: .constant(""),
                isFocused: .constant(true)
            )
            .frame(width: 240, height: 52)
        )
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.layoutIfNeeded()

        await fulfillment(of: [editingBegan], timeout: 2)

        let textField = findTextField(in: hostingController.view)
        XCTAssertTrue(textField?.isFirstResponder == true)
        XCTAssertEqual(textField?.keyboardType, .numberPad)
        XCTAssertEqual(textField?.textContentType, .oneTimeCode)
        window.isHidden = true
    }

    private func findTextField(in view: UIView) -> UITextField? {
        if let textField = view as? UITextField {
            return textField
        }
        for subview in view.subviews {
            if let textField = findTextField(in: subview) {
                return textField
            }
        }
        return nil
    }
}
