import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsURL = rootURL.appendingPathComponent("Assets", isDirectory: true)
let iconsetURL = assetsURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let previewURL = assetsURL.appendingPathComponent("AppAvatar.png")

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconVariants: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in iconVariants {
    let image = renderIcon(size: variant.size)
    try writePNG(image, to: iconsetURL.appendingPathComponent(variant.name))
}

try writePNG(renderIcon(size: 1024), to: previewURL)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c",
    "icns",
    iconsetURL.path,
    "-o",
    assetsURL.appendingPathComponent("AppIcon.icns").path
]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    throw NSError(
        domain: "FolderSorterIcon",
        code: Int(iconutil.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
    )
}

func renderIcon(size: Int) -> NSImage {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))

    image.lockFocus()
    defer { image.unlockFocus() }

    let bounds = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    NSColor.clear.setFill()
    bounds.fill()

    drawIcon(in: bounds)
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "FolderSorterIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to create PNG"]
        )
    }

    try pngData.write(to: url)
}

func drawIcon(in bounds: NSRect) {
    let scale = min(bounds.width, bounds.height) / 1024
    let canvas = NSRect(x: bounds.midX - 512 * scale, y: bounds.midY - 512 * scale, width: 1024 * scale, height: 1024 * scale)

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(
            x: canvas.minX + x * scale,
            y: canvas.minY + y * scale,
            width: width * scale,
            height: height * scale
        )
    }

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 34 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.set()

    let background = NSBezierPath(roundedRect: rect(70, 70, 884, 884), xRadius: 214 * scale, yRadius: 214 * scale)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.02, green: 0.31, blue: 0.36, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.50, blue: 0.48, alpha: 1),
        NSColor(calibratedRed: 0.92, green: 0.39, blue: 0.26, alpha: 1)
    ])
    gradient?.draw(in: background, angle: -38)

    NSGraphicsContext.saveGraphicsState()
    NSShadow().set()

    drawFileCard(rect(590, 410, 210, 260), accent: NSColor(calibratedRed: 0.19, green: 0.55, blue: 0.86, alpha: 1), scale: scale)
    drawFileCard(rect(512, 332, 210, 260), accent: NSColor(calibratedRed: 0.94, green: 0.31, blue: 0.44, alpha: 1), scale: scale)

    drawFolder(scale: scale, rect: rect)
    drawSortMarks(scale: scale, rect: rect)

    NSGraphicsContext.restoreGraphicsState()
}

func drawFileCard(_ cardRect: NSRect, accent: NSColor, scale: CGFloat) {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 14 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
    shadow.set()

    let card = NSBezierPath(roundedRect: cardRect, xRadius: 34 * scale, yRadius: 34 * scale)
    NSColor.white.withAlphaComponent(0.94).setFill()
    card.fill()

    NSShadow().set()
    accent.setFill()
    NSBezierPath(roundedRect: NSRect(x: cardRect.minX + 28 * scale, y: cardRect.maxY - 86 * scale, width: 154 * scale, height: 28 * scale), xRadius: 14 * scale, yRadius: 14 * scale).fill()
    accent.withAlphaComponent(0.55).setFill()
    NSBezierPath(roundedRect: NSRect(x: cardRect.minX + 28 * scale, y: cardRect.maxY - 134 * scale, width: 112 * scale, height: 24 * scale), xRadius: 12 * scale, yRadius: 12 * scale).fill()
    NSColor(calibratedWhite: 0.82, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: cardRect.minX + 28 * scale, y: cardRect.minY + 44 * scale, width: 154 * scale, height: 84 * scale), xRadius: 22 * scale, yRadius: 22 * scale).fill()
}

func drawFolder(scale: CGFloat, rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> NSRect) {
    let folderShadow = NSShadow()
    folderShadow.shadowBlurRadius = 22 * scale
    folderShadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    folderShadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    folderShadow.set()

    let tab = NSBezierPath(roundedRect: rect(205, 572, 310, 126), xRadius: 38 * scale, yRadius: 38 * scale)
    NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.24, alpha: 1).setFill()
    tab.fill()

    let body = NSBezierPath(roundedRect: rect(164, 272, 696, 368), xRadius: 70 * scale, yRadius: 70 * scale)
    let bodyGradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 0.73, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.96, green: 0.47, blue: 0.18, alpha: 1)
    ])
    bodyGradient?.draw(in: body, angle: -90)
}

func drawSortMarks(scale: CGFloat, rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> NSRect) {
    NSShadow().set()

    let lanes: [(NSColor, CGFloat)] = [
        (NSColor.white.withAlphaComponent(0.95), 525),
        (NSColor(calibratedRed: 0.06, green: 0.36, blue: 0.44, alpha: 1).withAlphaComponent(0.86), 450),
        (NSColor.white.withAlphaComponent(0.92), 375)
    ]

    for lane in lanes {
        lane.0.setFill()
        NSBezierPath(roundedRect: rect(260, lane.1, 370, 38), xRadius: 19 * scale, yRadius: 19 * scale).fill()
        NSBezierPath(roundedRect: rect(662, lane.1, 78, 38), xRadius: 19 * scale, yRadius: 19 * scale).fill()
    }

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: rect(0, 0, 0, 0).minX + 760 * scale, y: rect(0, 0, 0, 0).minY + 525 * scale))
    arrow.line(to: NSPoint(x: rect(0, 0, 0, 0).minX + 810 * scale, y: rect(0, 0, 0, 0).minY + 450 * scale))
    arrow.line(to: NSPoint(x: rect(0, 0, 0, 0).minX + 760 * scale, y: rect(0, 0, 0, 0).minY + 375 * scale))
    arrow.close()
    NSColor.white.withAlphaComponent(0.95).setFill()
    arrow.fill()
}
