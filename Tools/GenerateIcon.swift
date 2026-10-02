import AppKit

// Reproducible vector drawing for the app icon, without external image assets.
let destination = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.25, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let book = NSBezierPath(roundedRect: NSRect(x: 230, y: 190, width: 560, height: 644), xRadius: 72, yRadius: 72)
NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.94, alpha: 1).setFill()
book.fill()
let spine = NSBezierPath(roundedRect: NSRect(x: 265, y: 237, width: 485, height: 60), xRadius: 30, yRadius: 30)
NSColor(calibratedRed: 0.75, green: 0.9, blue: 0.78, alpha: 1).setFill()
spine.fill()
let graph = NSBezierPath()
graph.move(to: NSPoint(x: 347, y: 420))
graph.line(to: NSPoint(x: 467, y: 541))
graph.line(to: NSPoint(x: 556, y: 493))
graph.line(to: NSPoint(x: 679, y: 650))
graph.lineWidth = 46
graph.lineCapStyle = .round
graph.lineJoinStyle = .round
NSColor(calibratedRed: 0.12, green: 0.39, blue: 0.31, alpha: 1).setStroke()
graph.stroke()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
