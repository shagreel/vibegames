#!/usr/bin/env swift
// Samples RGB values down the centre column of a PNG to spot banding/seams.
// Usage: swift Tools/sample_column.swift <image.png> [x]
import AppKit

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
guard let image = NSImage(contentsOfFile: path),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
    fatalError("Could not read \(path)")
}

let width = bitmap.pixelsWide
let height = bitmap.pixelsHigh
let x = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : width / 2

print("image \(width)x\(height), sampling x=\(x)")

var previous: (Int, Int, Int)?
var maxJump = 0
var maxJumpY = 0

for y in stride(from: 0, to: height, by: 10) {
    guard let colour = bitmap.colorAt(x: x, y: y) else { continue }
    let r = Int(colour.redComponent * 255)
    let g = Int(colour.greenComponent * 255)
    let b = Int(colour.blueComponent * 255)

    if let p = previous {
        let jump = abs(r - p.0) + abs(g - p.1) + abs(b - p.2)
        if jump > maxJump {
            maxJump = jump
            maxJumpY = y
        }
    }
    if y % 100 == 0 || y > 1800 {
        print(String(format: "y=%4d  rgb(%3d,%3d,%3d)", y, r, g, b))
    }
    previous = (r, g, b)
}

print("largest neighbour delta in 10px steps: \(maxJump) at y=\(maxJumpY)")
