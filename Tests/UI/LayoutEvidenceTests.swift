import SwiftUI
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class LayoutEvidenceTests: XCTestCase {
    func testAppFontsAreRegistered() {
        for name in ["Pretendard-Regular", "Pretendard-Medium", "Pretendard-SemiBold", "Pretendard-Bold"] {
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
                ("saved", AnyView(SaveSuccessView(result: savedResult(photoVerification: .checked(photoURLCount: 2))))),
                (
                    "saved-partial",
                    AnyView(
                        SaveSuccessView(
                            result: savedResult(photoVerification: .unavailable(diagnosticCode: "FIXTURE"))
                        )
                    )
                ),
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
                let contentScrollViews = scrollViews.filter { !($0 is UITextView) }
                let scrollableKeyboardAwareScreens = ["work", "work-design", "rest", "rest-design", "thermometer", "profile", "withdrawal"]
                XCTAssertEqual(
                    contentScrollViews.count,
                    scrollableKeyboardAwareScreens.contains(name) ? 1 : 0,
                    "\(name): 키보드 대응 스크롤 컨테이너 수가 예상과 다릅니다"
                )
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

    private func savedResult(photoVerification: HGRecordPhotoVerification) -> HGRecordSaveResult {
        HGRecordSaveResult(
            recordID: "fixture",
            draft: HGRecordDraft(type: .work, memo: ""),
            expectedPhotoCount: 2,
            photoVerification: photoVerification,
            savedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
