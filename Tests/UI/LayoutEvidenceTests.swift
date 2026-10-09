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
            let views: [(String, AnyView)] = [
                ("login", AnyView(LoginView())),
                ("work", AnyView(WorkPhotoView())),
                ("rest", AnyView(RestPhotoView())),
                ("thermometer", AnyView(ThermometerRecordView())),
                ("field-photo", AnyView(FieldPhotoCaptureView())),
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
                await Task.yield()
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(size: size).image { _ in
                    host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                }
                XCTAssertEqual(image.size, size)
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(name)-\(Int(size.width))x\(Int(size.height))-fixture"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden = true
            }
        }
    }
}
