import XCTest

final class ChecklistUITests: XCTestCase {
    func testWorkerCanCheckAllItemsAndCompleteChecklist() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-checklist")
        app.launch()

        XCTAssertTrue(app.staticTexts["체크리스트"].waitForExistence(timeout: 10))

        let completionButton = app.buttons["checklist-complete"]
        XCTAssertTrue(completionButton.waitForExistence(timeout: 5))
        XCTAssertEqual(completionButton.label, "체크 완료 (3/6)")
        XCTAssertFalse(completionButton.isEnabled)

        for itemID in ["item-3", "item-4", "item-6"] {
            let item = app.buttons["checklist-item-\(itemID)"]
            XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing checklist row: \(itemID)")
            item.tap()
        }

        let completed = NSPredicate(format: "label == %@ AND isEnabled == true", "체크 완료")
        expectation(for: completed, evaluatedWith: completionButton)
        waitForExpectations(timeout: 5)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "checklist-complete-6-of-6"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
