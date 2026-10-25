import SwiftUI
import XCTest
@testable import heatguard_iOS

@MainActor
final class TextFieldKeyboardTests: XCTestCase {
    func testNumericFieldsUseNumericKeyboards() {
        XCTAssertEqual(HGTextFieldInputType.number.keyboardType, .numberPad)
        XCTAssertEqual(HGTextFieldInputType.decimal.keyboardType, .decimalPad)
        XCTAssertEqual(HGTextFieldInputType.phone.keyboardType, .phonePad)
    }
}
