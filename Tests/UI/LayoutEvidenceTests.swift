import SwiftUI
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class LayoutEvidenceTests: XCTestCase {
    func testDesignFontsAreRegistered() {
        for name in ["NotoSansKR-Regular", "NotoSansKR-Medium", "NotoSansKR-Bold"] {
            XCTAssertNotNil(UIFont(name: name, size: 14), name)
        }
    }

    func testRenderExistingFormsAtDesignAndSmallSizes() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for size in [CGSize(width: 402, height: 874), CGSize(width: 320, height: 568)] {
            let weather = HomeWeather(
                temperature: 30, humidity: 60, apparentTemperature: nil, heatLevel: nil,
                temperatureDelta: nil, comparisonTemperature: nil, observedAt: nil,
                skyStatus: nil, comparisonObservedAt: nil, comparisonBasis: nil
            )
            let views: [(String, AnyView)] = [
                ("login", AnyView(LoginView())),
                ("work", AnyView(WorkPhotoView())),
                ("work-design", AnyView(WorkPhotoView(weather: weather))),
                ("rest", AnyView(RestPhotoView())),
                ("rest-design", AnyView(RestPhotoView(weather: weather))),
                ("thermometer", AnyView(ThermometerRecordView())),
                ("field-photo", AnyView(FieldPhotoCaptureView())),
                ("emergency-prompt", AnyView(EmergencyAlertView())),
                ("emergency-active", AnyView(EmergencyCallView())),
                ("saved", AnyView(SaveSuccessView(result: HGRecordSaveResult(recordID: "fixture", draft: HGRecordDraft(type: .work, memo: ""), photoCount: 2, savedAt: Date(timeIntervalSince1970: 0))))),
                ("profile", AnyView(ProfileEditView())),
                ("withdrawal", AnyView(WithdrawalGuideView()))
            ]
            for (name, view) in views {
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                let host = UIHostingController(rootView: NavigationStack { view }.environment(\.colorScheme, .light))
                window.rootViewController = host
                window.makeKeyAndVisible()
                try await Task.sleep(for: .milliseconds(200))
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(size: size).image { _ in
                    host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                }
                XCTAssertEqual(image.size, size)
                let scrollViews = descendants(of: host.view).compactMap { $0 as? UIScrollView }
                XCTAssertTrue(scrollViews.allSatisfy { $0 is UITextView }, "\(name): 고정 화면에 스크롤 컨테이너가 남아 있습니다")
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(name)-\(Int(size.width))x\(Int(size.height))-fixture"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden = true
            }
        }
    }
    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
