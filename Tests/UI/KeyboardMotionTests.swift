import SwiftUI
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class KeyboardMotionTests: XCTestCase {
    func testLoginMovesInputFieldsOnlySlightlyAndReturnsWhenKeyboardHides() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: NavigationStack { LoginView() })
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(100))

        let emailField = try XCTUnwrap(descendants(of: host.view).compactMap { $0 as? UITextField }.first)
        let initialY = emailField.convert(emailField.bounds, to: window).minY
        let screenBounds = scene.screen.coordinateSpace.bounds
        let keyboardFrame = CGRect(
            x: 0,
            y: screenBounds.maxY - 300,
            width: screenBounds.width,
            height: 300
        )

        postKeyboardFrame(keyboardFrame)
        try await Task.sleep(for: .milliseconds(100))
        host.view.layoutIfNeeded()
        let keyboardVisibleY = emailField.convert(emailField.bounds, to: window).minY
        let inputShift = initialY - keyboardVisibleY
        XCTAssertGreaterThan(inputShift, 0)
        XCTAssertLessThan(inputShift, 40)

        postKeyboardFrame(CGRect(x: 0, y: screenBounds.maxY, width: screenBounds.width, height: 0))
        try await Task.sleep(for: .milliseconds(100))
        host.view.layoutIfNeeded()
        let restoredY = emailField.convert(emailField.bounds, to: window).minY
        XCTAssertEqual(restoredY, initialY, accuracy: 1)
        window.isHidden = true
    }

    private func postKeyboardFrame(_ frame: CGRect) {
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: frame,
                UIResponder.keyboardAnimationDurationUserInfoKey: 0.01,
                UIResponder.keyboardAnimationCurveUserInfoKey: UIView.AnimationCurve.easeInOut.rawValue
            ]
        )
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
