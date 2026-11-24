import SwiftUI
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class KeyboardMotionTests: XCTestCase {
    func testLoginLiftTracksKeyboardAndLeavesBottomGap() {
        XCTAssertEqual(HGKeyboardMotion.loginLift(keyboardHeight: 0, bottomSafeArea: 34), 0)
        XCTAssertEqual(HGKeyboardMotion.loginLift(keyboardHeight: 300, bottomSafeArea: 34), 250)
        XCTAssertEqual(HGKeyboardMotion.loginLift(keyboardHeight: 34, bottomSafeArea: 34), 0)
    }

    func testLoginScreenCompactsWithKeyboardAndReturnsWhenKeyboardHides() async throws {
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
        let didMoveForKeyboard = try await waitForLayout(on: host) {
            initialY - emailField.convert(emailField.bounds, to: window).minY > 0
        }
        XCTAssertTrue(didMoveForKeyboard, "키보드 표시 상태가 레이아웃에 반영되어야 합니다")
        let keyboardVisibleY = emailField.convert(emailField.bounds, to: window).minY
        let inputShift = initialY - keyboardVisibleY
        XCTAssertGreaterThan(inputShift, 0)
        XCTAssertLessThan(inputShift, 100, "키보드가 열려도 로그인 상단이 화면 밖으로 밀리면 안 됩니다")

        postKeyboardFrame(CGRect(x: 0, y: screenBounds.maxY, width: screenBounds.width, height: 0))
        let didRestoreAfterKeyboard = try await waitForLayout(on: host) {
            abs(emailField.convert(emailField.bounds, to: window).minY - initialY) <= 1
        }
        XCTAssertTrue(didRestoreAfterKeyboard, "키보드를 닫으면 입력 필드 위치가 복원되어야 합니다")
        let restoredY = emailField.convert(emailField.bounds, to: window).minY
        XCTAssertEqual(restoredY, initialY, accuracy: 1)
        window.isHidden = true
    }

    private func waitForLayout(
        on host: UIViewController,
        until condition: () -> Bool
    ) async throws -> Bool {
        for _ in 0..<100 {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return condition()
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
