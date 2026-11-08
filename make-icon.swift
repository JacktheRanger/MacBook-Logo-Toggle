// Composes the app icon from logo.svg: a light rounded tile with the black logo centred on it,
// written as the PNG sizes of an .iconset (iconutil then packs them into an .icns).
// Uses the SVG support built into NSImage, so there are no extra dependencies.
// Usage: swift make-icon.swift <logo.svg> <output .iconset directory>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let logo = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
  FileHandle.standardError.write("Usage: swift make-icon.swift <logo.svg> <out.iconset>\n".data(using: .utf8)!)
  exit(1)
}
let outDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(_ pixels: Int, to name: String) throws {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSGraphicsContext.current?.imageInterpolation = .high

  // macOS icon grid: an 824×824 rounded tile with a 185 corner radius on a 1024 canvas.
  let k = Double(pixels) / 1024
  let tile = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
  NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1).setFill()
  NSBezierPath(roundedRect: tile, xRadius: 185 * k, yRadius: 185 * k).fill()

  // The logo fills a bit more than half the tile's height, centred horizontally and nudged slightly up.
  let h = 824 * k * 0.62
  let w = h * logo.size.width / logo.size.height
  logo.draw(in: NSRect(x: (Double(pixels) - w) / 2, y: (Double(pixels) - h) / 2 + 8 * k, width: w, height: h))

  NSGraphicsContext.restoreGraphicsState()
  try rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}

// File names required by .iconset: icon_<points>x<points>[@2x].png
for points in [16, 32, 128, 256, 512] {
  try render(points, to: "icon_\(points)x\(points).png")
  try render(points * 2, to: "icon_\(points)x\(points)@2x.png")
}
