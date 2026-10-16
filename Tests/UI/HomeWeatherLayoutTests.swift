import SwiftUI
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class HomeWeatherLayoutTests: XCTestCase {
    func testDeltaBadgeKeepsMissingAndNegativeMeasurementsHonest() {
        XCTAssertNil(weather(delta: nil).temperatureDeltaBadgeText)
        XCTAssertEqual(weather(delta: -1.5).temperatureDeltaBadgeText, "▼ -1.5°C")
        XCTAssertEqual(weather(delta: 0).temperatureDeltaBadgeText, "• 0.0°C")
        XCTAssertEqual(weather(delta: 3.2).temperatureDeltaBadgeText, "▲ +3.2°C")
    }

    func testHomeFitsDesignAndSmallScreensWithoutScrollContainer() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let dashboard = HomeDashboard(
            companyName: "테스트 본사", companyPhone: nil, managerPhone: nil,
            siteName: "테스트 현장", teamName: "테스트 팀", workplace: "작업 현장",
            weather: weather(delta: 3.2),
            checklist: HGChecklistSummary(times: ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"], checkedCount: 3, totalCount: 6),
            unreadNotificationCount: 0
        )
        for size in [CGSize(width: 402, height: 978), CGSize(width: 402, height: 874), CGSize(width: 320, height: 568)] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            let host = UIHostingController(rootView: HomeView(initialDashboard: dashboard).environment(\.colorScheme, .light))
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            try await Task.sleep(for: .milliseconds(300))
            host.view.layoutIfNeeded()
            let scrollViews = descendants(of: host.view).compactMap { $0 as? UIScrollView }
            XCTAssertTrue(scrollViews.isEmpty, "홈은 스크롤 없이 전체 화면을 표시해야 합니다")
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "home-\(Int(size.width))x\(Int(size.height))-fixture"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func weather(delta: Double?) -> HomeWeather {
        HomeWeather(
            temperature: 47.5, humidity: 55, apparentTemperature: 40.5, heatLevel: 2,
            temperatureDelta: delta, comparisonTemperature: 44.3,
            observedAt: "2026-10-14T05:56:00+09:00", skyStatus: "PARTLY_CLOUDY",
            comparisonObservedAt: "2026-10-14T05:26:00+09:00", comparisonBasis: "PREVIOUS"
        )
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
