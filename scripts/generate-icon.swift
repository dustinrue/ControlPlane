#!/usr/bin/swift
/// Generates Resources/AppIcon.icns from the airplane silhouette source PNG.
///
/// Pipeline per size:
///   1. Fill canvas with ControlPlane blue (opaque background)
///   2. Begin transparency layer, fill white, mask by airplane alpha (.destinationIn)
///   3. Composite white airplane over blue
///
/// Run once after placing Resources/cp-icon-source.png:
///   swift scripts/generate-icon.swift
import AppKit

// MARK: - Resolve paths

let repoRoot: String = {
    let script = CommandLine.arguments[0]
    let scriptsDir = (script as NSString).deletingLastPathComponent
    return (scriptsDir as NSString).deletingLastPathComponent
}()

let sourcePath = "\(repoRoot)/Resources/cp-icon-source.png"
let iconsetDir = "/tmp/AppIcon.iconset"
let outputPath = "\(repoRoot)/Resources/AppIcon.icns"

// MARK: - Load source

guard let srcData   = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)),
      let srcBitmap = NSBitmapImageRep(data: srcData),
      let srcCG     = srcBitmap.cgImage
else {
    fputs("❌  Could not load \(sourcePath)\n", stderr); exit(1)
}

let srcW = srcBitmap.pixelsWide
let srcH = srcBitmap.pixelsHigh
print("Source: \(srcW)×\(srcH)px — \(sourcePath)")

// MARK: - Create white-airplane-on-blue CGImage at an arbitrary pixel size

// ControlPlane blue: #1B4F8C
let bgR: CGFloat = 0.106, bgG: CGFloat = 0.310, bgB: CGFloat = 0.549

func renderIconCGImage(pixels: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue:
        CGImageAlphaInfo.premultipliedFirst.rawValue |
        CGBitmapInfo.byteOrder32Little.rawValue
    )
    guard let ctx = CGContext(
        data: nil,
        width: pixels, height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else { fatalError("CGContext(\(pixels)) failed") }

    let rect = CGRect(x: 0, y: 0, width: pixels, height: pixels)

    // 1. Opaque blue background
    ctx.setFillColor(CGColor(srgbRed: bgR, green: bgG, blue: bgB, alpha: 1))
    ctx.fill(rect)

    // 2. White airplane (transparency layer):
    //    - fill layer white
    //    - mask with airplane's alpha via .destinationIn
    //    - endTransparencyLayer composites result (.normal) over blue
    ctx.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
    ctx.setBlendMode(.normal)
    ctx.setFillColor(CGColor.white)
    ctx.fill(rect)
    ctx.setBlendMode(.destinationIn)
    ctx.draw(srcCG, in: rect)
    ctx.endTransparencyLayer()

    guard let result = ctx.makeImage() else { fatalError("makeImage(\(pixels)) failed") }
    return result
}

// MARK: - Iconset variants

let variants: [(pixels: Int, name: String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

// MARK: - Prepare output directory

try? FileManager.default.removeItem(atPath: iconsetDir)
try  FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// MARK: - Render and save each size

for (pixels, name) in variants {
    let img = renderIconCGImage(pixels: pixels)
    let rep = NSBitmapImageRep(cgImage: img)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("❌  PNG encode failed for \(name)\n", stderr); continue
    }
    let dest = "\(iconsetDir)/\(name).png"
    do {
        try png.write(to: URL(fileURLWithPath: dest))
        print("  ✓  \(name).png  (\(pixels)×\(pixels)px)")
    } catch {
        fputs("❌  Write failed \(name): \(error)\n", stderr)
    }
}

// MARK: - iconutil → .icns

print("\nRunning iconutil…")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments     = ["-c", "icns", iconsetDir, "-o", outputPath]
try proc.run()
proc.waitUntilExit()

guard proc.terminationStatus == 0 else {
    fputs("❌  iconutil failed (exit \(proc.terminationStatus))\n", stderr); exit(1)
}
print("✅  AppIcon.icns → \(outputPath)")
