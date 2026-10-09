#!/usr/bin/env swift
//
// Renders the 1024pt App Store icon for Vibe Games.
// Usage: swift Tools/make_icon.swift Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
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

// Background: violet -> hot pink -> orange sweep.
let background = NSGradient(colors: [
    NSColor(srgbRed: 0.34, green: 0.13, blue: 0.70, alpha: 1),
    NSColor(srgbRed: 0.94, green: 0.20, blue: 0.44, alpha: 1),
    NSColor(srgbRed: 1.00, green: 0.58, blue: 0.20, alpha: 1)
])!
background.draw(in: NSRect(x: 0, y: 0, width: side, height: side), angle: -55)

// Soft glow behind the dial.
let glow = NSGradient(colors: [
    NSColor(white: 1, alpha: 0.28),
    NSColor(white: 1, alpha: 0.0)
])!
glow.draw(in: NSRect(x: center.x - 420, y: center.y - 420, width: 840, height: 840),
          relativeCenterPosition: .zero)

// Dial track: a full, faint ring.
let radius = side * 0.345
let lineWidth = side * 0.075

let track = NSBezierPath()
track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
track.lineWidth = lineWidth
NSColor(white: 1, alpha: 0.22).setStroke()
track.stroke()

// Dial progress: a bright arc running most of the way round, with a gap.
let progress = NSBezierPath()
progress.appendArc(withCenter: center,
                   radius: radius,
                   startAngle: 90,
                   endAngle: -215,
                   clockwise: true)
progress.lineWidth = lineWidth
progress.lineCapStyle = .round
NSColor.white.setStroke()
progress.stroke()

// The numeral.
let glyph = "5"
let baseFont = NSFont.systemFont(ofSize: side * 0.46, weight: .black)
let descriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
let font = NSFont(descriptor: descriptor, size: side * 0.46) ?? baseFont

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white
]
let string = NSAttributedString(string: glyph, attributes: attributes)
let textSize = string.size()
string.draw(at: NSPoint(x: center.x - textSize.width / 2,
                        y: center.y - textSize.height / 2 - font.descender / 2))

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
