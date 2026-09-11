import AppKit
import CoreImage
import MetalKit
import FoldCore

final class FoldRenderer: NSObject, MTKViewDelegate {
    let view: MTKView
    private let pipeline: MetalEffectPipeline
    private var textureCache: CVMetalTextureCache?
    private let inFlight = DispatchSemaphore(value: 2)
    private let commandQueue: MTLCommandQueue
    private let lock = NSLock()
    private var latestFrame: CVPixelBuffer?
    private var previewTexture: MTLTexture?
    private var receivedAt = ProcessInfo.processInfo.systemUptime
    var state = FoldState(angle: 180, settings: FoldSettings())
    var onFrameExpired: (() -> Void)?

    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let device, let queue = device.makeCommandQueue(),
              let pipeline = try? MetalEffectPipeline(device: device) else { return nil }
        commandQueue = queue
        self.pipeline = pipeline
        view = MTKView(frame: .zero, device: device)
        super.init()
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess else { return nil }
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.isPaused = true
        view.delegate = self
        view.autoresizingMask = [.width, .height]
    }

    func receive(_ frame: CVPixelBuffer) {
        lock.lock()
        latestFrame = frame
        receivedAt = ProcessInfo.processInfo.systemUptime
        lock.unlock()
    }

    func heartbeat() {
        lock.lock()
        receivedAt = ProcessInfo.processInfo.systemUptime
        lock.unlock()
    }

    func clear() {
        lock.lock()
        latestFrame = nil
        lock.unlock()
    }

    var hasFrame: Bool {
        lock.lock()
        defer { lock.unlock() }
        return latestFrame != nil
    }

    func setPreview(_ image: CIImage) {
        let context = CIContext()
        guard let cg = context.createCGImage(image, from: image.extent) else { return }
        previewTexture = try? MTKTextureLoader(device: pipeline.device).newTexture(cgImage: cg, options: [.SRGB: false, .generateMipmaps: true])
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        lock.lock()
        let frame = latestFrame
        let timestamp = receivedAt
        lock.unlock()
        if previewTexture == nil && ProcessInfo.processInfo.systemUptime - timestamp > 5 {
            onFrameExpired?()
            return
        }
        // Drop work rather than queue old frames and add visible input latency.
        guard inFlight.wait(timeout: .now()) == .success else { return }
        var mapped: CVMetalTexture?
        let source: MTLTexture
        if let previewTexture { source = previewTexture }
        else if let frame, let textureCache,
                CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, frame, nil, .bgra8Unorm,
                                                         CVPixelBufferGetWidth(frame), CVPixelBufferGetHeight(frame), 0, &mapped) == kCVReturnSuccess,
                let mapped, let texture = CVMetalTextureGetTexture(mapped) {
            source = texture
        } else { inFlight.signal(); return }
        guard let drawable = view.currentDrawable, let command = commandQueue.makeCommandBuffer(),
              pipeline.encode(source: source, destination: drawable.texture, state: state, command: command) else {
            inFlight.signal()
            return
        }
        let semaphore = inFlight
        command.addCompletedHandler { [frame, mapped] _ in
            withExtendedLifetime((frame, mapped)) {}
            semaphore.signal()
        }
        command.present(drawable)
        command.commit()
    }

    // Reference graph retained for regression comparisons, not used in live rendering.

    static func transformedImage(_ input: CIImage, bounds: CGRect, state: FoldState) -> CIImage {
        let width = bounds.width, height = bounds.height
        let origin = input.extent.origin
        var image = input.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
        image = image.transformed(by: CGAffineTransform(scaleX: width / image.extent.width, y: height / image.extent.height))
        let inset = width * state.inset
        image = image.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": CIVector(x: -inset, y: height * state.height),
            "inputTopRight": CIVector(x: width + inset, y: height * state.height),
            "inputBottomLeft": CIVector(x: 0, y: 0),
            "inputBottomRight": CIVector(x: width, y: 0)
        ]).cropped(to: bounds)
        // Radius is measured relative to display width, so preview and Retina output agree.
        let radius = state.blurRadius * width / 1440
        if radius > 0.01 {
            image = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: bounds)
        }
        // Core Image returns nil for a fully transparent gradient.
        guard state.darkness > 0 else { return image }
        let shadow = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0),
            "inputPoint1": CIVector(x: 0, y: height),
            "inputColor0": CIColor(red: 0, green: 0, blue: 0, alpha: state.darkness * 0.25),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: state.darkness)
        ])?.outputImage
        guard let shadow else { return image }
        return shadow.cropped(to: bounds).composited(over: image).cropped(to: bounds)
    }
}
