#!/usr/bin/env swift
//
// Renders the 1024pt App Store icon for Vibe Games.
// Usage: swift Tools/make_icon.swift Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// The icon is the suite's mark: four tiles, one per game, in that game's own
// gradient. It used to be Vibe Five's dial and numeral, which put one game's
// badge on all four — and made the app look like a buzzer timer to anyone who
// had not opened it.
//
// The same four tiles are the browser favicon, so the tab and the home screen
// carry one identity rather than two.
//
import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

let dimension = 1024
let side = CGFloat(dimension)
let center = NSPoint(x: side / 2, y: side / 2)

guard let ctx = CGContext(data: nil,
                          width: dimension,
                          height: dimension,
                          bitsPerComponent: 8,
                          bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Could not create bitmap context")
}

NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

func colour(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

// MARK: - Background
//
// Deep indigo rather than near-black: an icon this dark has to keep an edge
// against a dark wallpaper, and the four tiles need something to sit in.

let ink = NSGradient(colors: [colour(0x1B1836), colour(0x0E0D1B)])!
ink.draw(in: NSRect(x: 0, y: 0, width: side, height: side), angle: -60)

// A soft pool of light behind the mark, so the tiles look lit rather than pasted.
//
// Drawn as an explicit radial gradient whose radius ends *inside* the canvas
// edge but outside the corners. `NSGradient.draw(in:relativeCenterPosition:)`
// looked right and left a visible square seam where its rect stopped — about
// eight levels of a step, enough to see on a subtle background.
if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [NSColor(white: 1, alpha: 0.13).cgColor,
                                  NSColor(white: 1, alpha: 0.0).cgColor] as CFArray,
                         locations: [0, 1]) {
    ctx.drawRadialGradient(glow,
                           startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: side * 0.62,
                           options: [])
}

// MARK: - The mark

/// One tile, in the gradient of the game it stands for.
func drawTile(_ rect: NSRect, _ top: UInt32, _ bottom: UInt32) {
    let path = NSBezierPath(roundedRect: rect, xRadius: side * 0.072, yRadius: side * 0.072)

    // Drop shadow first, by filling the shape underneath it.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.34)
    shadow.shadowBlurRadius = side * 0.030
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.012)
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(colors: [colour(top), colour(bottom)])!
        .draw(in: rect, angle: -60)

    // A gloss across the upper half: enough to read as a raised tile.
    let gloss = NSGradient(colors: [
        NSColor(white: 1, alpha: 0.26),
        NSColor(white: 1, alpha: 0.0)
    ])!
    gloss.draw(in: NSRect(x: rect.minX, y: rect.midY,
                          width: rect.width, height: rect.height / 2),
               angle: -90)
    NSGraphicsContext.restoreGraphicsState()
}

let tile = side * 0.300
let gap = side * 0.044
let total = tile * 2 + gap
let originX = (side - total) / 2
let originY = (side - total) / 2

// Reading order, the same order the games are listed in the app and on the menu.
drawTile(NSRect(x: originX, y: originY + tile + gap, width: tile, height: tile),
         0xFF4757, 0xFF8C33)                                    // Vibe Five
drawTile(NSRect(x: originX + tile + gap, y: originY + tile + gap, width: tile, height: tile),
         0x21B8A8, 0x4585F5)                                    // Vibe Words
drawTile(NSRect(x: originX, y: originY, width: tile, height: tile),
         0x8549F0, 0xDB54C2)                                    // Vibe Sudoku
drawTile(NSRect(x: originX + tile + gap, y: originY, width: tile, height: tile),
         0xF7B929, 0x85D647)                                    // Vibe Trio

guard let image = ctx.makeImage() else {
    fatalError("Could not render image")
}

let url = URL(fileURLWithPath: outputPath)
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    "public.png" as CFString,
    1,
    nil
) else {
    fatalError("Could not create image destination at \(outputPath)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write \(outputPath)")
}
print("Wrote \(outputPath)")
