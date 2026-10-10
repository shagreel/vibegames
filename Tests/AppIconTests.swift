import XCTest
import UIKit
@testable import VibeGames

/// The icon is rendered by `Tools/make_icon.swift`, so nothing in the source
/// says what it looks like — and the App Store rejects an icon with any
/// transparency in it. Both are worth failing a build over rather than finding
/// out at submission.
final class AppIconTests: XCTestCase {

    /// Xcode writes derived copies of the icon into the app bundle. Their exact
    /// names depend on the device family, so this matches on the prefix.
    private func bundledIcons() -> [URL] {
        (Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("AppIcon") }
    }

    func testTheAppShipsAnIcon() {
        XCTAssertFalse(bundledIcons().isEmpty,
                       "no AppIcon PNG made it into the bundle — the asset catalog is broken")
    }

    /// Every pixel, not the channel.
    ///
    /// Xcode's derived copies are RGBA whatever the source is, so the presence
    /// of an alpha channel says nothing — what the App Store rejects is an icon
    /// with pixels you can see through.
    func testTheIconHasNoTransparentPixels() {
        for url in bundledIcons() {
            guard let image = UIImage(contentsOfFile: url.path) else {
                return XCTFail("could not read \(url.lastPathComponent)")
            }
            XCTAssertTrue(isFullyOpaque(image),
                          "\(url.lastPathComponent) has see-through pixels; "
                          + "the App Store rejects a transparent icon")
        }
    }

    private func isFullyOpaque(_ image: UIImage) -> Bool {
        guard let source = image.cgImage else { return false }
        let width = source.width
        let height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return false }

        for index in stride(from: 3, to: pixels.count, by: 4) where pixels[index] != 255 {
            return false
        }
        return true
    }

    func testTheIconIsSquareAndNotEmpty() {
        for url in bundledIcons() {
            guard let image = UIImage(contentsOfFile: url.path) else {
                return XCTFail("could not read \(url.lastPathComponent)")
            }
            XCTAssertEqual(image.size.width, image.size.height,
                           "\(url.lastPathComponent) is not square")
            XCTAssertGreaterThanOrEqual(image.size.width, 60,
                                        "\(url.lastPathComponent) is too small to be the icon")
        }
    }
}
