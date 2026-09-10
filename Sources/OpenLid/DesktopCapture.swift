import AppKit
import ScreenCaptureKit
import CoreMedia

final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "org.openlid.frames", qos: .userInteractive)
    private let renderer: FoldRenderer
    var onFailure: ((String) -> Void)?

    init(renderer: FoldRenderer) { self.renderer = renderer }

    @MainActor func start(displayID: CGDirectDisplayID) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.unavailableDisplay
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        guard !ownApps.isEmpty else { throw CaptureError.missingExclusion }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        // Bounded memory and GPU load; 30fps at up to 1920px wide for the first release.
        let scale = min(1, 1920.0 / Double(display.width))
        config.width = Int(Double(display.width) * scale)
        config.height = Int(Double(display.height) * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        self.stream = stream
        try await stream.startCapture()
    }

    @MainActor func stop() async {
        let previous = stream
        stream = nil
        try? await previous?.stopCapture()
        // Flush callbacks before dropping the retained frame.
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume()
            }
        }
        renderer.clear()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw) else { return }
        if status == .complete, let image = buffer.imageBuffer {
            renderer.receive(image)
        }
        if status == .idle { renderer.heartbeat() }
        // No image is retained for blank, stopped, or suspended output.
        if status == .blank || status == .suspended || status == .stopped {
            DispatchQueue.main.async { [weak self] in self?.onFailure?("Screen capture paused by macOS. Enable again when ready.") }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onFailure?(error.localizedDescription) }
    }

    enum CaptureError: LocalizedError {
        case unavailableDisplay, missingExclusion
        var errorDescription: String? {
            switch self {
            case .unavailableDisplay: "The built-in display is unavailable. Open the MacBook lid and try again."
            case .missingExclusion: "Could not safely exclude OpenLid from capture. Relaunch the app and try again."
            }
        }
    }
}
