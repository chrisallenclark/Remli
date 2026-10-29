import XCTest

/// Walks the iOS app through the screens the Android app is matching, saving a screenshot
/// of each to `REFERENCE_DIR` on the host (simulator processes share the Mac's filesystem).
///
/// Written to keep going: a step that cannot find its control still takes the next
/// screenshot, so one renamed button costs one image rather than the whole set.
final class ReferenceScreens: XCTestCase {

    private var outDir = URL(fileURLWithPath: NSTemporaryDirectory())
    private var prefix = "light"
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        if let dir = env["REFERENCE_DIR"] { outDir = URL(fileURLWithPath: dir) }
        if let appearance = env["APPEARANCE"] { prefix = appearance }
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        // The app treats this variable as "running under test" and opens an in-memory,
        // CloudKit-free store — so every run starts empty and nothing touches iCloud.
        app.launchEnvironment["XCTestConfigurationFilePath"] = "reference-screens"
    }

    private func shot(_ name: String) {
        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: outDir.appendingPathComponent("\(prefix)_\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func button(labelBeginsWith text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    private func button(labelContains text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func capture(body: String, name: String?) {
        let capture = app.buttons["Capture"]
        guard capture.waitForExistence(timeout: 10) else { return }
        capture.tap()

        let editor = app.textViews.firstMatch
        if editor.waitForExistence(timeout: 5) {
            editor.tap()
            editor.typeText(body)
        }
        if let name {
            let field = app.textFields["Name it (optional)"]
            if field.waitForExistence(timeout: 2) {
                field.tap()
                field.typeText(name)
            }
        }
        if name != nil { shot("03_capture_typed") }
        app.buttons["Save"].tap()
        sleep(1)
    }

    func testReferenceScreens() {
        app.launch()
        _ = app.buttons["Capture"].waitForExistence(timeout: 15)
        shot("01_ideas_empty")

        app.buttons["Capture"].tap()
        _ = app.textViews.firstMatch.waitForExistence(timeout: 5)
        shot("02_capture_empty")
        app.buttons["Cancel"].tap()
        sleep(1)

        capture(body: "Weekend market stall selling cold brew in returnable glass bottles", name: nil)
        capture(body: "Call the accountant about the quarterly VAT return", name: nil)
        capture(
            body: "A pop-up supper club that only serves dishes from one grandmother's recipe book each month",
            name: "Grandmother's supper club"
        )
        // Enrichment runs after capture; on the simulator that is the heuristic engine.
        sleep(4)
        shot("04_ideas_list")

        let row = button(labelContains: "supper club")
        if row.waitForExistence(timeout: 5) {
            row.press(forDuration: 1.2)
            shot("05_context_menu")
            let pin = app.buttons["Pin"]
            if pin.waitForExistence(timeout: 2) { pin.tap() } else { app.tap() }
            sleep(1)
            shot("06_ideas_pinned")
        }

        if row.exists {
            row.tap()
            sleep(1)
            shot("07_detail")

            let major = button(labelBeginsWith: "Major")
            if major.waitForExistence(timeout: 3) {
                major.tap()
                shot("08_detail_importance_set")
            }

            app.swipeUp()
            shot("09_detail_scrolled")
            app.swipeDown()

            let more = app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
            if more.exists {
                more.tap()
                shot("10_detail_menu")
                let edit = app.buttons["Edit"]
                if edit.waitForExistence(timeout: 2) {
                    edit.tap()
                    shot("11_detail_editing")
                } else {
                    app.tap()
                }
            }

            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        for label in ["Settings", "gearshape", "Gear"] {
            let settings = app.buttons[label]
            if settings.exists {
                settings.tap()
                shot("12_settings")
                break
            }
        }
    }
}
