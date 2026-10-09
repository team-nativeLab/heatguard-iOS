import SwiftUI
import XCTest
@testable import heatguard_iOS

@MainActor
final class FixedContentTests: XCTestCase {
    func testDesignContentIsNeverEnlarged() {
        XCTAssertEqual(HGFixedContent<EmptyView>.scale(contentHeight: 600, availableHeight: 700), 1)
    }

    func testShortScreenKeepsEntireContentInsideHeight() {
        let scale = HGFixedContent<EmptyView>.scale(contentHeight: 800, availableHeight: 480)
        XCTAssertEqual(scale, 0.6, accuracy: 0.001)
        XCTAssertLessThanOrEqual(800 * scale, 480)
    }
}
