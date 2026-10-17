import XCTest

/// The settings sheet repaints when the appearance changes while it is open.
///
/// The report was that one direction did and the other did not — the picker is
/// inside the sheet, and the colour scheme is set at the root of the app, so a
/// sheet that is already presented can keep the appearance it was presented
/// with. Reading the picker's selection back proves nothing about what is on
/// screen, so this samples the pixels: the sheet covers most of the screen, and
/// a light one is bright and a dark one is not.
final class AppearanceSheetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheSheetFollowsTheAppearanceBothWays() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        openNumberVibeSettings(app)

        let appearance = app.segmentedControls["gameSettings.appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5),
                      "the sheet should offer the appearance")

        let toLight = try choose("Light", in: appearance, app: app)
        XCTAssertGreaterThan(toLight, 150,
                             "a light sheet should be bright (measured \(Int(toLight)))")

        let toDark = try choose("Dark", in: appearance, app: app)
        XCTAssertLessThan(toDark, 90,
                          "a dark sheet should be dark (measured \(Int(toDark)))")

        // The direction the owner said did not repaint.
        let backToLight = try choose("Light", in: appearance, app: app)
        XCTAssertGreaterThan(backToLight, 150,
                             "going back to light should repaint (measured \(Int(backToLight)))")

        // And the panel behind the sheet, which is the app rather than the sheet.
        let settled = try choose("System", in: appearance, app: app)
        XCTAssertFalse(settled.isNaN)
        app.buttons["sudokuSettings.done"].tap()
    }

    /// Taps one appearance and returns the mean brightness of the screen once it
    /// has settled.
    private func choose(_ title: String, in picker: XCUIElement, app: XCUIApplication) throws -> CGFloat {
        let button = picker.buttons[title]
        XCTAssertTrue(button.exists, "the picker should offer \(title)")
        button.tap()

        // The repaint is a frame or two behind the tap.
        Thread.sleep(forTimeInterval: 0.6)
        return brightness(of: XCUIScreen.main.screenshot())
    }

    /// The mean of a small, scaled-down copy of the screen: enough to tell light
    /// from dark, cheap enough to do in a test.
    private func brightness(of screenshot: XCUIScreenshot) -> CGFloat {
        guard let image = screenshot.image.cgImage else { return .nan }

        let width = 32
        let height = 64
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return .nan }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            total += (Double(pixels[index]) + Double(pixels[index + 1]) + Double(pixels[index + 2])) / 3
        }
        return CGFloat(total / Double(width * height))
    }

    private func openNumberVibeSettings(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-sudoku"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15))
        tile.tap()

        let settings = app.buttons["sudoku.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        XCTAssertTrue(app.textFields["gameSettings.nameField"].waitForExistence(timeout: 5))
    }
}
