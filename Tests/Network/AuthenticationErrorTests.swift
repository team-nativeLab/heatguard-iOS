import XCTest
@testable import heatguard_iOS

@MainActor
final class AuthenticationErrorTests: XCTestCase {
    func testInvalidCredentialsAreNotReportedAsExpiredSession() {
        let error = HGAPIError.server(message: "현재 비밀번호가 올바르지 않습니다.", statusCode: 401, serverCode: "INVALID_CREDENTIALS")
        XCTAssertEqual(error.failureTitle, "로그인 정보를 확인해주세요")
        XCTAssertEqual(error.errorDescription, "현재 비밀번호가 올바르지 않습니다.")
        XCTAssertEqual(error.diagnosticCode, "HTTP 401 · INVALID_CREDENTIALS")
    }

    func testDisabledAccountIsNotReportedAsExpiredSession() {
        let error = HGAPIError.server(message: "비활성화된 계정입니다.", statusCode: 403, serverCode: "ACCOUNT_DISABLED")
        XCTAssertEqual(error.failureTitle, "비활성화된 계정입니다")
        XCTAssertEqual(error.errorDescription, "비활성화된 계정입니다.")
    }

    func testUnknownUnauthorizedResponseRetainsSessionExpiryTitle() {
        XCTAssertEqual(HGAPIError.server(message: "세션이 유효하지 않습니다.", statusCode: 401, serverCode: "UNAUTHORIZED").failureTitle, "인증이 만료됐습니다")
    }

    func testMissingUnauthorizedCodeRetainsSessionExpiryTitle() {
        XCTAssertEqual(HGAPIError.server(message: "Unauthorized", statusCode: 401, serverCode: nil).failureTitle, "인증이 만료됐습니다")
    }

    func testForbiddenResponseHasPermissionTitle() {
        XCTAssertEqual(HGAPIError.server(message: "권한이 없습니다.", statusCode: 403, serverCode: "FORBIDDEN").failureTitle, "접근 권한이 없습니다")
    }

    func testMissingForbiddenCodeHasPermissionTitle() {
        XCTAssertEqual(HGAPIError.server(message: "Forbidden", statusCode: 403, serverCode: nil).failureTitle, "접근 권한이 없습니다")
    }

    func testOtherErrorsKeepExistingTitles() {
        XCTAssertEqual(HGAPIError.authenticationRequired.failureTitle, "로그인이 필요합니다")
        XCTAssertEqual(HGAPIError.server(message: "서버 오류", statusCode: 500, serverCode: nil).failureTitle, "서버 요청 오류")
    }
}
