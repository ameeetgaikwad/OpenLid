import AppKit
import ScreenCaptureKit
import CoreMedia

final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "org.openlid.frames", qos: .userInteractive)
    private let renderer: FoldRenderer
    var onFailure: ((String) -> Void)?

    init(renderer: FoldRenderer) { self.renderer = renderer }

    @MainActor func start(displayID: CGDirectDisplayID, overlay: NSPanel, pixelSize: CGSize, sourceRect: CGRect) async throws {
        // Register an empty transparent panel before filtering. It cannot obscure the desktop.
        overlay.orderFrontRegardless()
        defer { overlay.orderOut(nil) }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        try Task.checkCancellation()
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.unavailableDisplay
        }
        guard let excluded = content.windows.first(where: {
            $0.windowID == CGWindowID(overlay.windowNumber) &&
            $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier
        }) else { throw CaptureError.missingExclusion }
        let filter = SCContentFilter(display: display, excludingWindows: [excluded])
        let config = SCStreamConfiguration()
        // Display-local coordinates use a top-left origin. Match the below-menu
        // overlay exactly instead of scaling a full-display capture into it.
        config.sourceRect = sourceRect
        let scale = min(1, 3840 / pixelSize.width)
        config.width = max(1, Int(pixelSize.width * scale))
        config.height = max(1, Int(pixelSize.height * scale))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        config.colorSpaceName = CGColorSpace.sRGB
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        self.stream = stream
        try await stream.startCapture()
        for _ in 0..<150 {
            try Task.checkCancellation()
            if renderer.hasFrame { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw CaptureError.noFrames
    }

    @MainActor func stop() async {
        let previous = stream
        stream = nil
        try? await previous?.stopCapture()
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume() }
        }
        renderer.clear()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw) else { return }
        if status == .complete, let image = buffer.imageBuffer { renderer.receive(image) }
        if status == .idle { renderer.heartbeat() }
        if status == .blank || status == .suspended || status == .stopped {
            DispatchQueue.main.async { [weak self] in self?.onFailure?("Screen capture paused by macOS.") }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onFailure?(error.localizedDescription) }
    }

    enum CaptureError: LocalizedError {
        case unavailableDisplay, missingExclusion, noFrames
        var errorDescription: String? {
            switch self {
            case .unavailableDisplay: "The built-in display is unavailable."
            case .missingExclusion: "Could not identify the effect overlay. Capture was not started."
            case .noFrames: "No desktop frames arrived. Check Screen Recording access and relaunch."
            }
        }
    }
}
