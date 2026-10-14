import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// The Y-tick: a Y whose long right arm also reads as a check.
/// Drawn on the same 100x100 grid as the approved design, then measured and
/// centred — the short left arm leaves the mark leaning right otherwise.
func markPath(scale s: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 30 * s, y: 38 * s))
    path.addLine(to: CGPoint(x: 46 * s, y: 58 * s))
    path.addLine(to: CGPoint(x: 76 * s, y: 22 * s))
    path.move(to: CGPoint(x: 46 * s, y: 58 * s))
    path.addLine(to: CGPoint(x: 46 * s, y: 80 * s))
    return path
}

func render(size: CGFloat, background: CGColor, ink: CGColor, to url: URL) -> Bool {
    let space = CGColorSpaceCreateDeviceRGB()
    // noneSkipLast keeps the PNG opaque; App Store icons may not carry alpha.
    guard let ctx = CGContext(
        data: nil,
        width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return false }

    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)

    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let s = size / 100.0
    let width = 11 * s
    let path = markPath(scale: s)

    // Measure the stroked outline, not the skeleton, so the round caps count.
    let outline = path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let bounds = outline.boundingBoxOfPath
    let dx = (size - bounds.width) / 2 - bounds.minX
    let dy = (size - bounds.height) / 2 - bounds.minY

    ctx.translateBy(x: dx, y: dy)
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(path)
    ctx.strokePath()

    FileHandle.standardError.write(
        "  mark \(Int(bounds.width))x\(Int(bounds.height)) of \(Int(size)), nudged \(Int(dx)),\(Int(dy))\n".data(using: .utf8)!
    )

    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
              url as CFURL, UTType.png.identifier as CFString, 1, nil
          ) else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let white = rgb(255, 255, 255)
let ink = rgb(11, 11, 12)

let jobs: [(String, CGColor, CGColor)] = [
    ("icon-light.png", white, ink),
    ("icon-dark.png", ink, white),
    // Tinted icons are supplied light-on-dark; iOS maps the luminance.
    ("icon-tinted.png", ink, white)
]

for (name, bg, fg) in jobs {
    print(render(size: 1024, background: bg, ink: fg, to: out.appendingPathComponent(name))
          ? "wrote \(name)" : "FAILED \(name)")
}
