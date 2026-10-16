import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class RecordDraftIsolationTests: XCTestCase {
    func testAccountsCannotLoadOrDeleteEachOthersDrafts() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = HGRecordDraftStore(ownerID: "first-user", rootDirectory: root)
        let second = HGRecordDraftStore(ownerID: "second-user", rootDirectory: root)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        try first.save(draft: HGRecordDraft(type: .work, memo: "first private memo"), images: [image])
        XCTAssertNil(try second.load())
        try second.save(draft: HGRecordDraft(type: .rest, memo: "second memo"), images: [image])
        XCTAssertEqual(try first.load()?.draft.memo, "first private memo")
        XCTAssertEqual(try second.load()?.draft.memo, "second memo")
        try first.clear()
        XCTAssertNil(try first.load())
        XCTAssertEqual(try second.load()?.draft.memo, "second memo")
    }

    func testMissingAccountCannotSaveOrReadDraft() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HGRecordDraftStore(ownerID: nil, rootDirectory: root)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        XCTAssertNil(try store.load())
        XCTAssertThrowsError(try store.save(draft: HGRecordDraft(type: .work, memo: ""), images: [image]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testLegacyUnownedDraftIsNotLoadedAndIsRemoved() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appending(path: "photos"), withIntermediateDirectories: true)
        try Data("legacy private data".utf8).write(to: root.appending(path: "draft.json"))
        let store = HGRecordDraftStore(ownerID: "new-user", rootDirectory: root)
        XCTAssertNil(try store.load())
        try store.clearLegacyDraft()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "draft.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "photos").path))
    }

    func testAccountIdentityIsResetOnLoginAndLogout() throws {
        let suite = "draft-session-fixture-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = HGSessionStateStore(userDefaults: defaults)
        state.setUserID("old-user")
        state.markSignedIn()
        XCTAssertNil(state.userID)
        XCTAssertFalse(state.isSignedOut)
        state.setUserID("new-user")
        state.markSignedOut()
        XCTAssertNil(state.userID)
        XCTAssertTrue(state.isSignedOut)
    }
}
