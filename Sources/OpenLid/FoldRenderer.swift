import AppKit
import CoreImage
import MetalKit
import FoldCore

/// Core Image renders the perspective transform and blur directly into a Metal drawable.
final class FoldRenderer: NSObject, MTKViewDelegate {
    let view: MTKView
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let lock = NSLock()
    private var latestFrame: CVPixelBuffer?
    private var receivedAt = Date.distantPast
    var state = FoldState(angle: 180, settings: FoldSettings())
    var onFrameExpired: (() -> Void)?

    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let device, let queue = device.makeCommandQueue() else { return nil }
        commandQueue = queue
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        view = MTKView(frame: .zero, device: device)
        super.init()
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 30
        view.isPaused = true
        view.delegate = self
    }

    func receive(_ frame: CVPixelBuffer) {
        lock.lock()
        latestFrame = frame
        receivedAt = Date()
        lock.unlock()
    }

    func clear() {
        lock.lock()
        latestFrame = nil
        receivedAt = .distantPast
        lock.unlock()
    }

    func heartbeat() {
        lock.lock()
        if latestFrame != nil { receivedAt = Date() }
        lock.unlock()
    }

    var hasFrame: Bool {
        lock.lock()
        defer { lock.unlock() }
        return latestFrame != nil
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        lock.lock()
        let frame = latestFrame
        let timestamp = receivedAt
        lock.unlock()
        guard let frame else { return }
        // ScreenCaptureKit can send idle frames; refreshes are tracked by the capture output.
        guard Date().timeIntervalSince(timestamp) < 3 else {
            onFrameExpired?()
            return
        }
        guard let drawable = view.currentDrawable, let command = commandQueue.makeCommandBuffer() else { return }
        let width = CGFloat(drawable.texture.width), height = CGFloat(drawable.texture.height)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let output = Self.transformedImage(CIImage(cvPixelBuffer: frame), bounds: bounds, state: state)
        context.render(output, to: drawable.texture, commandBuffer: command, bounds: bounds,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        command.present(drawable)
        command.commit()
    }

    static func transformedImage(_ input: CIImage, bounds: CGRect, state: FoldState) -> CIImage {
        let width = bounds.width, height = bounds.height
        var image = input
        image = image.transformed(by: CGAffineTransform(scaleX: width / image.extent.width, y: height / image.extent.height))
        if state.blurRadius > 0.1 {
            image = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: state.blurRadius]).cropped(to: bounds)
        }
        let inset = width * state.inset
        image = image.applyingFilter("CIPerspectiveTransform", parameters: [
            // The approaching top edge widens; the bottom hinge stays fixed.
            "inputTopLeft": CIVector(x: -inset, y: height * state.height),
            "inputTopRight": CIVector(x: width + inset, y: height * state.height),
            "inputBottomLeft": CIVector(x: 0, y: 0),
            "inputBottomRight": CIVector(x: width, y: 0)
        ])
        let shade = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: state.darkness)).cropped(to: bounds)
        let background = CIImage(color: .black).cropped(to: bounds)
        return shade.composited(over: image.composited(over: background))
    }
}
