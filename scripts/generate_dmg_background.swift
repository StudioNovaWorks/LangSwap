#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - CLI Options

struct Options {
    var outPath: String = "Resources/dmg_background.tiff"
    var version: String?
    var previewPath: String?
}

func parseOptions() -> Options {
    var opts = Options()
    var i = 1
    let args = CommandLine.arguments
    while i < args.count {
        switch args[i] {
        case "--out":
            i += 1
            guard i < args.count else {
                fputs("Error: --out requires a path argument\n", stderr)
                exit(2)
            }
            opts.outPath = args[i]
        case "--version":
            i += 1
            guard i < args.count else {
                fputs("Error: --version requires a value\n", stderr)
                exit(2)
            }
            opts.version = args[i]
        case "--preview":
            i += 1
            guard i < args.count else {
                fputs("Error: --preview requires a path argument\n", stderr)
                exit(2)
            }
            opts.previewPath = args[i]
        case "-h", "--help":
            print("""
            Usage: generate_dmg_background.swift [--out <tiff_path>] [--version <ver>] [--preview <png_path>]
            """)
            exit(0)
        default:
            fputs("Error: Unknown argument: \(args[i])\n", stderr)
            exit(2)
        }
        i += 1
    }
    return opts
}

// MARK: - Helpers

func resolveProjectRoot() -> URL {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("Info.plist").path) {
        return cwd
    }
    let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let candidate = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Info.plist").path) {
        return candidate
    }
    return cwd
}

func resolveVersion(explicit: String?, projectRoot: URL) -> String {
    if let explicit, !explicit.isEmpty {
        return explicit
    }
    let infoPlistURL = projectRoot.appendingPathComponent("Info.plist")
    if let data = try? Data(contentsOf: infoPlistURL),
       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
       let ver = plist["CFBundleShortVersionString"] as? String,
       !ver.isEmpty
    {
        return ver
    }
    return "1.0.0"
}

func hexColor(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func drawText(
    _ string: String,
    at point: NSPoint,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    maxWidth: CGFloat? = nil
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: string, attributes: attrs)
    if let maxWidth {
        let size = attributed.boundingRect(
            with: NSSize(width: maxWidth, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        let xOrigin: CGFloat
        switch alignment {
        case .right:
            xOrigin = point.x - maxWidth
        case .center:
            xOrigin = point.x - maxWidth / 2.0
        default:
            xOrigin = point.x
        }
        attributed.draw(in: NSRect(x: xOrigin, y: point.y, width: maxWidth, height: ceil(size.height) + 4))
    } else {
        attributed.draw(at: point)
    }
}

func drawVectorArrow(
    in cg: CGContext,
    center: CGPoint,
    length: CGFloat,
    headSize: CGFloat,
    thickness: CGFloat,
    color: NSColor
) {
    cg.saveGState()
    cg.setStrokeColor(color.cgColor)
    cg.setLineWidth(thickness)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)

    let halfLen = length / 2.0
    let startX = center.x - halfLen
    let tipX = center.x + halfLen
    let wingX = tipX - headSize
    let wingY = headSize * 0.72

    // Horizontal shaft
    cg.move(to: CGPoint(x: startX, y: center.y))
    cg.addLine(to: CGPoint(x: tipX, y: center.y))
    cg.strokePath()

    // Chevron head
    cg.move(to: CGPoint(x: wingX, y: center.y - wingY))
    cg.addLine(to: CGPoint(x: tipX, y: center.y))
    cg.addLine(to: CGPoint(x: wingX, y: center.y + wingY))
    cg.strokePath()
    cg.restoreGState()
}

func drawStepGuide(
    in cg: CGContext,
    number: String,
    japaneseTitle: String,
    englishSubtitle: String,
    originX: CGFloat,
    centerY: CGFloat
) {
    // Circular step badge
    let badgeSize: CGFloat = 22.0
    let badgeRect = CGRect(
        x: originX,
        y: centerY - badgeSize / 2.0,
        width: badgeSize,
        height: badgeSize
    )
    cg.saveGState()
    cg.setFillColor(hexColor(0x1D1D1F).cgColor)
    cg.fillEllipse(in: badgeRect)
    cg.restoreGState()

    let numFont = NSFont.systemFont(ofSize: 11.5, weight: .bold)
    let numAttrs: [NSAttributedString.Key: Any] = [
        .font: numFont,
        .foregroundColor: NSColor.white,
    ]
    let numStr = NSAttributedString(string: number, attributes: numAttrs)
    let numSize = numStr.size()
    numStr.draw(at: NSPoint(
        x: badgeRect.midX - numSize.width / 2.0,
        y: badgeRect.midY - numSize.height / 2.0 - 0.5
    ))

    // Equal-size Japanese & English text stack (12.5 pt)
    let textX = originX + badgeSize + 10.0
    let jaFont = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
    let enFont = NSFont.systemFont(ofSize: 12.5, weight: .regular)
    drawText(
        japaneseTitle,
        at: NSPoint(x: textX, y: centerY - 19.0),
        font: jaFont,
        color: hexColor(0x1D1D1F)
    )
    drawText(
        englishSubtitle,
        at: NSPoint(x: textX, y: centerY + 2.0),
        font: enFont,
        color: hexColor(0x606673)
    )
}

// MARK: - DMG Background Renderer

struct DMGLayout {
    static let widthPt: CGFloat = 600.0
    static let heightPt: CGFloat = 400.0
    static let titleBarPt: CGFloat = 28.0
    static let iconSizePt: CGFloat = 96.0
    static let appIconCenter = CGPoint(x: 160.0, y: 144.0)
    static let appsIconCenter = CGPoint(x: 440.0, y: 144.0)
    static let splitAnchor = CGPoint(x: 300.0, y: 144.0)
    // Exact 12.0 deg vertical tilt matching Resources/AppIcon.png diagonal divider
    static let splitSlopeFromVertical: CGFloat = tan(12.0 * .pi / 180.0)
}

func drawBackgroundScene(in cg: CGContext, version: String) {
    let w = DMGLayout.widthPt
    let h = DMGLayout.heightPt

    // 1. Diagonal 2-tone split (x(y) = anchor.x + tan(12°) * (anchor.y - y))
    let topX = DMGLayout.splitAnchor.x + DMGLayout.splitSlopeFromVertical * DMGLayout.splitAnchor.y
    let bottomX = DMGLayout.splitAnchor.x - DMGLayout.splitSlopeFromVertical * (h - DMGLayout.splitAnchor.y)

    cg.saveGState()
    cg.beginPath()
    cg.move(to: CGPoint(x: 0, y: 0))
    cg.addLine(to: CGPoint(x: topX, y: 0))
    cg.addLine(to: CGPoint(x: bottomX, y: h))
    cg.addLine(to: CGPoint(x: 0, y: h))
    cg.closePath()
    cg.setFillColor(hexColor(0xFAFBFD).cgColor)
    cg.fillPath()

    cg.beginPath()
    cg.move(to: CGPoint(x: topX, y: 0))
    cg.addLine(to: CGPoint(x: w, y: 0))
    cg.addLine(to: CGPoint(x: w, y: h))
    cg.addLine(to: CGPoint(x: bottomX, y: h))
    cg.closePath()
    cg.setFillColor(hexColor(0xEEF0F5).cgColor)
    cg.fillPath()

    // Crisp 1.0 pt hairline along the 12° split
    cg.beginPath()
    cg.move(to: CGPoint(x: topX, y: 0))
    cg.addLine(to: CGPoint(x: bottomX, y: h))
    cg.setStrokeColor(hexColor(0xDCE0EA).cgColor)
    cg.setLineWidth(1.0)
    cg.strokePath()
    cg.restoreGState()

    // 2. Top Header
    drawText(
        "LangSwap",
        at: NSPoint(x: 32.0, y: 22.0),
        font: NSFont.systemFont(ofSize: 15.0, weight: .bold),
        color: hexColor(0x1D1D1F)
    )
    drawText(
        "v\(version)  \u{00B7}  Studio Nova Works",
        at: NSPoint(x: 568.0, y: 25.0),
        font: NSFont.systemFont(ofSize: 11.0, weight: .medium),
        color: hexColor(0x707785),
        alignment: .right,
        maxWidth: 260.0
    )

    // 3. Center Simple Vector Arrow (no dark circle badge)
    drawVectorArrow(
        in: cg,
        center: DMGLayout.splitAnchor,
        length: 68.0,
        headSize: 11.0,
        thickness: 2.8,
        color: hexColor(0x4A505E)
    )

    // 4. Bottom 2-Step Guide Card
    let cardRect = CGRect(x: 28.0, y: 276.0, width: 544.0, height: 92.0)
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 14.0, cornerHeight: 14.0, transform: nil)

    cg.saveGState()
    // Note: in a flipped context scaled (scale, -scale), Quartz base-space negative height casts shadow downward.
    cg.setShadow(
        offset: CGSize(width: 0.0, height: -4.0),
        blur: 14.0,
        color: NSColor(calibratedWhite: 0.0, alpha: 0.06).cgColor
    )
    cg.addPath(cardPath)
    cg.setFillColor(hexColor(0xFFFFFF, alpha: 0.97).cgColor)
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(cardPath)
    cg.setStrokeColor(hexColor(0xD3D8E2).cgColor)
    cg.setLineWidth(1.0)
    cg.strokePath()
    cg.restoreGState()

    let cardMidY = cardRect.midY
    drawStepGuide(
        in: cg,
        number: "1",
        japaneseTitle: "Applications \u{3078}\u{30C9}\u{30E9}\u{30C3}\u{30B0}",
        englishSubtitle: "Drag to Applications",
        originX: 46.0,
        centerY: cardMidY
    )

    drawVectorArrow(
        in: cg,
        center: CGPoint(x: 300.0, y: cardMidY),
        length: 14.0,
        headSize: 5.5,
        thickness: 1.8,
        color: hexColor(0x9EA4B2)
    )

    drawStepGuide(
        in: cg,
        number: "2",
        japaneseTitle: "Applications \u{304B}\u{3089}\u{8D77}\u{52D5}",
        englishSubtitle: "Open from Applications",
        originX: 324.0,
        centerY: cardMidY
    )
}

func drawFinderPreviewOverlay(in cg: CGContext, projectRoot: URL) {
    let w = DMGLayout.widthPt
    let barH = DMGLayout.titleBarPt

    // Simulated macOS Finder titlebar chrome
    cg.saveGState()
    cg.setFillColor(hexColor(0xF3F4F6).cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: w, height: barH))
    cg.setFillColor(hexColor(0xD8DCE3).cgColor)
    cg.fill(CGRect(x: 0, y: barH - 1.0, width: w, height: 1.0))

    let lights: [(CGFloat, UInt32)] = [(16.0, 0xFF5F57), (36.0, 0xFEBC2E), (56.0, 0x28C840)]
    for (cx, colorHex) in lights {
        cg.setFillColor(hexColor(colorHex).cgColor)
        cg.fillEllipse(in: CGRect(x: cx - 6.0, y: barH / 2.0 - 6.0, width: 12.0, height: 12.0))
    }
    cg.restoreGState()

    drawText(
        "LangSwap",
        at: NSPoint(x: w / 2.0, y: 6.0),
        font: NSFont.systemFont(ofSize: 13.0, weight: .semibold),
        color: hexColor(0x3A3A3C),
        alignment: .center,
        maxWidth: 180.0
    )

    // Simulated Finder icons (offset vertically by titlebar height)
    let iconSize = DMGLayout.iconSizePt
    let appIconURL = projectRoot.appendingPathComponent("Resources/AppIcon.png")
    if let appImage = NSImage(contentsOf: appIconURL) {
        let rect = NSRect(
            x: DMGLayout.appIconCenter.x - iconSize / 2.0,
            y: barH + DMGLayout.appIconCenter.y - iconSize / 2.0,
            width: iconSize,
            height: iconSize
        )
        appImage.draw(in: rect)
    }

    let appsImage = NSWorkspace.shared.icon(forFile: "/Applications")
    let appsRect = NSRect(
        x: DMGLayout.appsIconCenter.x - iconSize / 2.0,
        y: barH + DMGLayout.appsIconCenter.y - iconSize / 2.0,
        width: iconSize,
        height: iconSize
    )
    appsImage.draw(in: appsRect)

    let labelFont = NSFont.systemFont(ofSize: 12.0, weight: .medium)
    let labelY = barH + DMGLayout.appIconCenter.y + iconSize / 2.0 + 10.0
    drawText(
        "LangSwap.app",
        at: NSPoint(x: DMGLayout.appIconCenter.x, y: labelY),
        font: labelFont,
        color: hexColor(0x1D1D1F),
        alignment: .center,
        maxWidth: 140.0
    )
    drawText(
        "Applications",
        at: NSPoint(x: DMGLayout.appsIconCenter.x, y: labelY),
        font: labelFont,
        color: hexColor(0x1D1D1F),
        alignment: .center,
        maxWidth: 140.0
    )
}

func renderPNG(
    widthPt: CGFloat,
    heightPt: CGFloat,
    scale: Int,
    to fileURL: URL,
    draw: (CGContext) -> Void
) throws {
    let pxW = Int(widthPt) * scale
    let pxH = Int(heightPt) * scale

    // Use a raw 1:1 pixel CGContext rather than NSGraphicsContext(bitmapImageRep:) to avoid double-scaling.
    guard let cg = CGContext(
        data: nil,
        width: pxW,
        height: pxH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "GenerateDMGBackground", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate CGContext"])
    }

    cg.interpolationQuality = .high
    cg.translateBy(x: 0.0, y: CGFloat(pxH))
    cg.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))

    let nsCtx = NSGraphicsContext(cgContext: cg, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    draw(cg)
    nsCtx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = cg.makeImage() else {
        throw NSError(domain: "GenerateDMGBackground", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"])
    }

    let dpi = 72.0 * CGFloat(scale)
    let props: [CFString: Any] = [
        kCGImagePropertyDPIWidth: dpi,
        kCGImagePropertyDPIHeight: dpi,
    ]
    guard let dest = CGImageDestinationCreateWithURL(
        fileURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "GenerateDMGBackground", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG destination"])
    }
    CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "GenerateDMGBackground", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG"])
    }
}

func combineHiDPITiff(oneXURL: URL, twoXURL: URL, outURL: URL) throws {
    let parentDir = outURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
    process.arguments = ["-cathidpicheck", oneXURL.path, twoXURL.path, "-out", outURL.path]

    let errPipe = Pipe()
    process.standardError = errPipe
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
        throw NSError(
            domain: "GenerateDMGBackground",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "tiffutil failed: \(errMsg)"]
        )
    }
}

// MARK: - Main

do {
    let opts = parseOptions()
    let projectRoot = resolveProjectRoot()
    let version = resolveVersion(explicit: opts.version, projectRoot: projectRoot)

    let outURL = URL(fileURLWithPath: opts.outPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("langswap_dmg_bg_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let oneXURL = tempDir.appendingPathComponent("dmg_bg.png")
    let twoXURL = tempDir.appendingPathComponent("dmg_bg@2x.png")

    try renderPNG(widthPt: DMGLayout.widthPt, heightPt: DMGLayout.heightPt, scale: 1, to: oneXURL) { cg in
        drawBackgroundScene(in: cg, version: version)
    }
    try renderPNG(widthPt: DMGLayout.widthPt, heightPt: DMGLayout.heightPt, scale: 2, to: twoXURL) { cg in
        drawBackgroundScene(in: cg, version: version)
    }
    try combineHiDPITiff(oneXURL: oneXURL, twoXURL: twoXURL, outURL: outURL)
    print("✅ Generated HiDPI DMG background TIFF: \(outURL.path) (v\(version), 600x400pt @1x/@2x)")

    if let previewPath = opts.previewPath {
        let previewURL = URL(fileURLWithPath: previewPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
        try FileManager.default.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try renderPNG(
            widthPt: DMGLayout.widthPt,
            heightPt: DMGLayout.heightPt + DMGLayout.titleBarPt,
            scale: 2,
            to: previewURL
        ) { cg in
            cg.saveGState()
            cg.translateBy(x: 0.0, y: DMGLayout.titleBarPt)
            drawBackgroundScene(in: cg, version: version)
            cg.restoreGState()
            drawFinderPreviewOverlay(in: cg, projectRoot: projectRoot)
        }
        print("🖼️ Generated Retina preview PNG: \(previewURL.path)")
    }
} catch {
    fputs("❌ Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
