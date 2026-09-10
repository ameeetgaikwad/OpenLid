import AppKit

// Original vector artwork, rasterized with the macOS SDK; no downloaded assets.
let output = CommandLine.arguments[1]
func png(_ name: String, width: Int, height: Int, draw: () -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output + "/" + name))
}
let green = NSColor(srgbRed: 0.125, green: 0.235, blue: 0.216, alpha: 1)
let cream = NSColor(srgbRed: 0.965, green: 0.969, blue: 0.945, alpha: 1)
try png("icon.png", width: 1024, height: 1024) {
    green.setFill()
    NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 200, yRadius: 200).fill()
    cream.setStroke()
    let lid = NSBezierPath()
    lid.move(to: NSPoint(x: 270, y: 355)); lid.line(to: NSPoint(x: 340, y: 720))
    lid.line(to: NSPoint(x: 775, y: 650)); lid.line(to: NSPoint(x: 710, y: 355))
    lid.line(to: NSPoint(x: 270, y: 355)); lid.lineWidth = 34; lid.lineJoinStyle = .round; lid.stroke()
    let base = NSBezierPath(); base.move(to: NSPoint(x: 230, y: 300)); base.line(to: NSPoint(x: 790, y: 300))
    base.lineWidth = 34; base.lineCapStyle = .round; base.stroke()
}
try png("installer.png", width: 660, height: 420) {
    cream.setFill(); NSRect(x: 0, y: 0, width: 660, height: 420).fill()
    func label(_ text: String, y: CGFloat, size: CGFloat, bold: Bool = false) {
        let attributes: [NSAttributedString.Key: Any] = [.font: bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size), .foregroundColor: green]
        let string = text as NSString; let width = string.size(withAttributes: attributes).width
        string.draw(at: NSPoint(x: (660 - width) / 2, y: y), withAttributes: attributes)
    }
    label("Make your Mac a little more alive.", y: 345, size: 24, bold: true)
    label("Drag OpenLid into Applications", y: 305, size: 17)
    green.withAlphaComponent(0.45).setStroke()
    let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: 293, y: 212)); arrow.line(to: NSPoint(x: 367, y: 212))
    arrow.move(to: NSPoint(x: 353, y: 226)); arrow.line(to: NSPoint(x: 367, y: 212)); arrow.line(to: NSPoint(x: 353, y: 198))
    arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.stroke()
    label("Then open OpenLid from Applications.", y: 65, size: 15)
    label("Alpha preview · Not notarized", y: 30, size: 12)
}
