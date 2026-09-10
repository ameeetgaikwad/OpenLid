import AppKit
import Combine
import FoldCore

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: FoldSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings.sanitized()) {
                UserDefaults.standard.set(data, forKey: "foldSettings")
            }
        }
    }
    @Published var previewAngle = 72.0
    @Published private(set) var sensorAngle: Double?
    @Published private(set) var sensorStatus = "Checking lid sensor…"
    @Published private(set) var status = "Ready to preview. Your screen is not being captured."
    @Published private(set) var enabled = false
    @Published private(set) var busy = false
    @Published private(set) var permissionGranted = false
    var showPermissionHelper: (() -> Void)?

    private let sensor = LidSensor()
    private var renderer: FoldRenderer?
    private var capture: DesktopCapture?
    private var overlay: NSPanel?
    private var timer: Timer?
    private var startTask: Task<Void, Never>?
    private var generation = 0
    private var failedReads = 0
    private var effectSince: Date?
    private var observers: [NSObjectProtocol] = []
    private var lockObserver: NSObjectProtocol?
    private var escapeMonitor: Any?

    init() {
        if let data = UserDefaults.standard.data(forKey: "foldSettings"),
           let saved = try? JSONDecoder().decode(FoldSettings.self, from: data) {
            settings = saved.sanitized()
        } else { settings = FoldSettings() }
        permissionGranted = CGPreflightScreenCaptureAccess()
        checkSensor()
        let center = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                      NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.pause(message: "Paused for sleep or session change. Enable again when ready.") }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause(message: "Display configuration changed. Enable again when ready.") }
        })
        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pause(message: "Paused while the screen is locked.") }
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor in self?.pause() }
            }
            return event
        }
    }

    func checkSensor() {
        guard !enabled, !busy else { return }
        sensorAngle = sensor.connect()
        sensorStatus = sensorAngle.map { "Lid sensor available · \(Int($0))°" }
            ?? "No readable lid sensor. Manual preview is still available."
        sensor.disconnect()
        permissionGranted = CGPreflightScreenCaptureAccess()
    }

    func openPermissionSettings() {
        // Only invoked by a clearly labelled user action. Never requests Accessibility.
        showPermissionHelper?()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func refreshPermission() {
        permissionGranted = CGPreflightScreenCaptureAccess()
    }

    func enable() {
        guard !enabled, !busy else { return }
        permissionGranted = CGPreflightScreenCaptureAccess()
        guard permissionGranted else {
            status = "Screen Recording access is required for the live effect. Allow OpenLid in System Settings, then relaunch."
            // macOS presents its normal permission flow only after this explicit button click.
            _ = CGRequestScreenCaptureAccess()
            openPermissionSettings()
            return
        }
        guard let angle = sensor.connect() else {
            sensorStatus = "No readable lid sensor. Try Recheck hardware; this model may be unsupported."
            status = "Live effect unavailable. Use the manual preview to explore styles."
            sensor.disconnect()
            return
        }
        sensorAngle = angle
        guard let screen = NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) else {
            sensor.disconnect()
            status = "Open the built-in MacBook display to enable the effect."
            return
        }
        guard let renderer = FoldRenderer() else {
            sensor.disconnect()
            status = "A Metal-capable graphics device is required."
            return
        }
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.contentView = renderer.view
        renderer.view.frame = CGRect(origin: .zero, size: screen.frame.size)
        generation += 1
        let run = generation
        renderer.onFrameExpired = { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == run else { return }
                self.pause(message: "Capture stopped updating. Paused to restore your desktop.")
            }
        }
        let session = DesktopCapture(renderer: renderer)
        session.onFailure = { [weak self] message in
            Task { @MainActor in
                guard let self, self.generation == run else { return }
                self.pause(message: "Capture stopped: \(message)")
            }
        }
        self.renderer = renderer
        capture = session
        overlay = panel
        busy = true
        status = "Starting local screen capture…"
        startTask = Task { [weak self] in
            do {
                try await session.start(displayID: screen.displayID)
                guard let self, self.generation == run, !Task.isCancelled else { return }
                self.enabled = true
                self.busy = false
                self.status = "Following your lid. Pause from the menu bar at any time."
                self.failedReads = 0
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.tick() }
                }
            } catch {
                guard let self, self.generation == run else { return }
                self.pause(message: "Could not start capture: \(error.localizedDescription)")
            }
        }
    }

    private func tick() {
        guard enabled, let renderer else { return }
        guard let angle = sensor.read() else {
            failedReads += 1
            if failedReads >= 5 { pause(message: "Lid sensor stopped responding. Paused to restore your desktop.") }
            return
        }
        failedReads = 0
        sensorAngle = angle
        let state = FoldState(angle: angle, settings: settings)
        renderer.state = state
        if state.isActive && renderer.hasFrame {
            if effectSince == nil { effectSince = Date() }
            if let effectSince, Date().timeIntervalSince(effectSince) > 15 {
                pause(message: "Paused after 15 seconds of continuous folding. Reopen the lid, then enable again.")
                return
            }
            renderer.view.isPaused = false
            overlay?.orderFrontRegardless()
        } else {
            effectSince = nil
            overlay?.orderOut(nil)
            renderer.view.isPaused = true
        }
    }

    func pause(message: String = "Paused. Your screen is not being captured.") {
        generation += 1
        enabled = false
        timer?.invalidate()
        timer = nil
        sensor.disconnect()
        overlay?.orderOut(nil)
        renderer?.view.isPaused = true
        effectSince = nil
        status = message
        guard let previous = capture else { return }
        previous.onFailure = nil
        capture = nil
        busy = true
        let pendingStart = startTask
        pendingStart?.cancel()
        startTask = nil
        Task { [weak self] in
            // Await an in-flight start before stopping; rapid pause cannot orphan a stream.
            await pendingStart?.value
            await previous.stop()
            self?.renderer = nil
            self?.overlay = nil
            self?.busy = false
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
