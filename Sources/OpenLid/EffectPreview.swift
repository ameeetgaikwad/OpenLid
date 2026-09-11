import AppKit
import SwiftUI
import CoreImage
import FoldCore

struct EffectPreview: NSViewRepresentable {
    let angle: Double
    let settings: FoldSettings
    final class Coordinator {
        let renderer = FoldRenderer()
        var lastState: FoldState?
        init() { renderer?.setPreview(PreviewArtwork.image()) }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView {
        guard let renderer = context.coordinator.renderer else {
            return NSTextField(labelWithString: "Metal preview unavailable")
        }
        renderer.view.enableSetNeedsDisplay = true
        return renderer.view
    }
    func updateNSView(_ view: NSView, context: Context) {
        let state = FoldState(angle: angle, settings: settings)
        guard context.coordinator.lastState != state else { return }
        context.coordinator.lastState = state
        context.coordinator.renderer?.state = state
        view.needsDisplay = true
    }
}

enum PreviewArtwork {
    /// Generated artwork only. Live and preview share the same transform and shading code.
    static func image() -> CIImage {
        let image = NSImage(size: NSSize(width: 1440, height: 900), flipped: false) { bounds in
            NSColor(white: 0.90, alpha: 1).setFill(); bounds.fill()
            NSColor(white: 0.82, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 85, y: 95, width: 1270, height: 700), xRadius: 26, yRadius: 26).fill()
            NSColor(white: 0.97, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 260, y: 155, width: 920, height: 595), xRadius: 18, yRadius: 18).fill()
            let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 65, weight: .medium), .foregroundColor: NSColor(white: 0.18, alpha: 1)]
            ("Take it slow." as NSString).draw(at: NSPoint(x: 350, y: 510), withAttributes: title)
            let subtitle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 23), .foregroundColor: NSColor(white: 0.40, alpha: 1)]
            ("Your desktop. One continuous motion." as NSString).draw(at: NSPoint(x: 352, y: 455), withAttributes: subtitle)
            NSColor(white: 0.78, alpha: 1).setFill()
            for y in [290, 345, 400] { NSRect(x: 350, y: y, width: 650, height: 12).fill() }
            NSColor(white: 0.55, alpha: 1).setFill()
            for x in stride(from: 525, through: 885, by: 60) {
                NSBezierPath(roundedRect: NSRect(x: x, y: 25, width: 40, height: 40), xRadius: 10, yRadius: 10).fill()
            }
            return true
        }
        var rect = NSRect(x: 0, y: 0, width: 1440, height: 900)
        return CIImage(cgImage: image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!)
    }
}
