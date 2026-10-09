#!/usr/bin/env swift
// Samples specific pixels so colour claims can be verified rather than eyeballed.
// Usage: swift Tools/sample_points.swift <image.png> <label:x,y> [label:x,y ...]
import AppKit

let args = CommandLine.arguments
guard args.count > 2, let image = NSImage(contentsOfFile: args[1]),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
    fatalError("usage: sample_points.swift <image.png> <label:x,y> ...")
}

print("image \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
for spec in args.dropFirst(2) {
    let parts = spec.split(separator: ":")
    guard parts.count == 2 else { continue }
    let coords = parts[1].split(separator: ",").compactMap { Int($0) }
    guard coords.count == 2, let colour = bitmap.colorAt(x: coords[0], y: coords[1]) else {
        print("  \(parts[0]): unreadable")
        continue
    }
    let r = Int(colour.redComponent * 255)
    let g = Int(colour.greenComponent * 255)
    let b = Int(colour.blueComponent * 255)
    print(String(format: "  %-14s (%4d,%4d)  rgb(%3d,%3d,%3d)", (parts[0] as NSString).utf8String!, coords[0], coords[1], r, g, b))
}
