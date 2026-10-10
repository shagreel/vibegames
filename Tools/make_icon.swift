#!/usr/bin/env swift
//
// Renders the 1024pt App Store icon for Vibe Games, and the matching favicon.
//
//   swift Tools/make_icon.swift <icon.png> [favicon.svg]
//
// The mark is "VG" — the suite's initials — set in the system's rounded heavy
// face, slanted, and filled with a sweep through all four game colours. The
// letterform is the app's own voice: the interface is rounded and heavy
// throughout, so the icon speaks the same language.
//
// This was Vibe Five's dial and numeral, then four tiles; both put a game's
// badge on the whole suite.
//
import AppKit
import CoreText

let arguments = CommandLine.arguments
let outputPath = arguments.count > 1 ? arguments[1] : "icon-1024.png"
let faviconPath = arguments.count > 2 ? arguments[2] : nil

let dimension = 1024
let side = CGFloat(dimension)
let center = CGPoint(x: side / 2, y: side / 2)

// MARK: - Palette

func colour(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
func cg(_ hex: UInt32) -> CGColor { colour(hex).cgColor }

// One colour per game, in the order the games are listed in the app.
let five:   UInt32 = 0xFF4757
let trio:   UInt32 = 0xF7B929
let words:  UInt32 = 0x21B8A8
let sudoku: UInt32 = 0x8549F0

/// Where the four-colour sweep starts and ends, as a fraction of the canvas. A
/// little inside the edges so the first and last colours get some width rather
/// than only appearing at the very corner.
let sweepStart = side * 0.10
let sweepEnd = side * 0.90

// MARK: - The mark

/// The glyph outlines of `text`, kerned tight.
func outlines(_ text: String, _ font: NSFont, tracking: CGFloat) -> CGPath {
    let attributed = NSAttributedString(string: text, attributes: [.font: font, .kern: tracking])
    let line = CTLineCreateWithAttributedString(attributed)
    let ctFont = font as CTFont
    let path = CGMutablePath()

    for case let run as CTRun in CTLineGetGlyphRuns(line) as NSArray {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, count), &positions)
        for index in 0..<count {
            guard let glyph = CTFontCreatePathForGlyph(ctFont, glyphs[index], nil) else { continue }
            path.addPath(glyph, transform: CGAffineTransform(translationX: positions[index].x,
                                                             y: positions[index].y))
        }
    }
    return path
}

/// The system's rounded design at its heaviest — the same face the app's own
/// headings use, so the icon is set in the product's voice rather than in a
/// lookalike.
func roundedHeavy(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    if let descriptor = base.fontDescriptor.withDesign(.rounded),
       let font = NSFont(descriptor: descriptor, size: size) {
        return font
    }
    return base
}

/// Centres the mark and scales it into the icon, so the shape can be drawn at
/// whatever size is convenient without landing off-centre or cropped.
func normalised(_ path: CGPath, target: CGFloat) -> CGPath {
    let box = path.boundingBoxOfPath
    guard box.width > 0, box.height > 0 else { return path }
    let scale = min(target / box.width, target / box.height)
    var transform = CGAffineTransform(translationX: -box.midX, y: -box.midY)
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
    return path.copy(using: &transform)!
}

let mark: CGPath = {
    let base = outlines("VG", roundedHeavy(side * 0.5), tracking: -side * 0.012)
    // Slanted, which is what makes it read as italic. Positive leans the top
    // right; the negative version is a backward italic and looks wrong.
    var shear = CGAffineTransform(a: 1, b: 0, c: 0.20, d: 1, tx: 0, ty: 0)
    return normalised(base.copy(using: &shear)!, target: side * 0.66)
}()

// MARK: - Rendering

/// Deep indigo rather than near-black: an icon this dark has to keep an edge
/// against a dark wallpaper, and the mark needs something to sit in.
func drawBackground(_ ctx: CGContext) {
    let ink = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [cg(0x1B1836), cg(0x0E0D1B)] as CFArray,
                         locations: [0, 1])!
    ctx.drawLinearGradient(ink,
                           start: CGPoint(x: 0, y: side),
                           end: CGPoint(x: side, y: 0),
                           options: [])

    // A pool of light behind the mark, so it looks lit rather than pasted.
    //
    // An explicit radial gradient whose radius ends inside the canvas edge but
    // outside the corners: the obvious `NSGradient.draw(in:relativeCenterPosition:)`
    // leaves a visible square seam where its rect stops.
    if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: [NSColor(white: 1, alpha: 0.13).cgColor,
                                      NSColor(white: 1, alpha: 0).cgColor] as CFArray,
                             locations: [0, 1]) {
        ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: side * 0.62, options: [])
    }
}

func drawMark(_ ctx: CGContext) {
    // Shadow first, by filling the same outline in black. The gradient below
    // covers that fill entirely, so only the shadow itself shows.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -side * 0.018),
                  blur: side * 0.05,
                  color: NSColor(white: 0, alpha: 0.5).cgColor)
    ctx.addPath(mark)
    ctx.setFillColor(cg(0x000000))
    ctx.fillPath()
    ctx.restoreGState()

    let sweep = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [cg(five), cg(trio), cg(words), cg(sudoku)] as CFArray,
                           locations: [0, 0.34, 0.67, 1])!
    ctx.saveGState()
    ctx.addPath(mark)
    ctx.clip()
    ctx.drawLinearGradient(sweep,
                           start: CGPoint(x: sweepStart, y: center.y),
                           end: CGPoint(x: sweepEnd, y: center.y),
                           // Fills either side of the run, so no part of the
                           // mark is left unpainted and showing the black.
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

guard let ctx = CGContext(data: nil,
                          width: dimension,
                          height: dimension,
                          bitsPerComponent: 8,
                          bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Could not create bitmap context")
}
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

drawBackground(ctx)
drawMark(ctx)

guard let image = ctx.makeImage() else { fatalError("Could not render image") }
guard let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outputPath) as CFURL, "public.png" as CFString, 1, nil
) else {
    fatalError("Could not create image destination at \(outputPath)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write \(outputPath)")
}
print("Wrote \(outputPath)")

// MARK: - The favicon
//
// Written from the *same* glyph outlines rather than redrawn by hand, so the tab
// and the home screen cannot drift apart. The path is emitted in icon space and
// the SVG scales it, which is why nothing here is rounded down to 64.

if let faviconPath {
    func svgPath(_ path: CGPath) -> String {
        var out = ""
        // CoreGraphics is y-up; SVG is y-down.
        func point(_ p: CGPoint) -> String {
            String(format: "%.1f %.1f", p.x, side - p.y)
        }
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                out += "M\(point(points[0]))"
            case .addLineToPoint:
                out += "L\(point(points[0]))"
            case .addQuadCurveToPoint:
                out += "Q\(point(points[0])) \(point(points[1]))"
            case .addCurveToPoint:
                out += "C\(point(points[0])) \(point(points[1])) \(point(points[2]))"
            case .closeSubpath:
                out += "Z"
            @unknown default:
                break
            }
        }
        return out
    }

    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(dimension) \(dimension)">
      <!--
        The Vibe Games mark. Generated by Tools/make_icon.swift from the same
        glyph outlines as the app icon, so the tab and the home screen carry one
        identity. Do not edit by hand.
      -->
      <defs>
        <linearGradient id="ink" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#1b1836"/><stop offset="1" stop-color="#0e0d1b"/>
        </linearGradient>
        <linearGradient id="sweep" gradientUnits="userSpaceOnUse"
                        x1="\(Int(sweepStart))" y1="0" x2="\(Int(sweepEnd))" y2="0"
                        spreadMethod="pad">
          <stop offset="0" stop-color="#ff4757"/>
          <stop offset="0.34" stop-color="#f7b929"/>
          <stop offset="0.67" stop-color="#21b8a8"/>
          <stop offset="1" stop-color="#8549f0"/>
        </linearGradient>
        <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stop-color="#ffffff" stop-opacity="0.13"/>
          <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
        </radialGradient>
      </defs>

      <rect width="\(dimension)" height="\(dimension)" fill="url(#ink)"/>
      <rect width="\(dimension)" height="\(dimension)" fill="url(#glow)"/>
      <path d="\(svgPath(mark))" fill="url(#sweep)"/>
    </svg>

    """
    try! svg.write(toFile: faviconPath, atomically: true, encoding: .utf8)
    print("Wrote \(faviconPath)")
}
