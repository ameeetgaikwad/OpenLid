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
    @Published private(set) var status = "Ready to preview. Live mode uses local screen capture."
    @Published private(set) var enabled = false
    @Published private(set) var busy = false

    private let sensor = SensorSampler()
    @Published private(set) var permissionGranted = false
    private var renderer: FoldRenderer?
    private var capture: DesktopCapture?
    private var startTask: Task<Void, Never>?
    private var generation = 0
    private var overlay: NSPanel?
    private var timer: Timer?
    private var motion = LidMotion(angle: 180)
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastAnglePublication = 0.0
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
                Task { @MainActor [weak self] in self?.pause(message: "Paused for sleep or session change. Enable again when ready.") }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause(message: "Display configuration changed. Enable again when ready.") }
        })
        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause(message: "Paused while the screen is locked.") }
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in self?.pause() }
            }
            return event
        }
    }

    func checkSensor() {
        guard !enabled, !busy else { return }
        busy = true
        let run = generation
        Task { [weak self] in
            guard let self else { return }
            let angle = await self.sensor.probe()
            defer { self.busy = false }
            guard self.generation == run else { return }
            self.sensorAngle = angle
            self.sensorStatus = angle.map { "Lid sensor available · \(Int($0))°" }
                ?? "No readable lid sensor. Manual preview is still available."
        }
    }

    func openPermissionSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func enable() {
        guard !enabled, !busy else { return }
        permissionGranted = CGPreflightScreenCaptureAccess()
        if !permissionGranted {
            permissionGranted = CGRequestScreenCaptureAccess()
            if !permissionGranted {
                status = "Allow OpenLid in Screen Recording settings, then quit and reopen it."
                return
            }
            // Continue only if the permission grant is immediately usable.
        }
        guard let screen = NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) else {
            status = "Open the built-in MacBook display to enable the effect."
            return
        }
        guard let renderer = FoldRenderer() else {
            status = "Metal rendering is unavailable on this Mac."
            return
        }
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // The panel remains empty and transparent until it is excluded from capture.
        generation += 1
        let run = generation
        let session = DesktopCapture(renderer: renderer)
        session.onFailure = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self, self.generation == run else { return }
                self.pause(message: "Capture stopped: \(message)")
            }
        }
        renderer.onFrameExpired = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == run else { return }
                self.pause(message: "Capture stopped updating. Overlay hidden.")
            }
        }
        self.renderer = renderer
        capture = session
        overlay = panel
        busy = true
        status = "Starting local screen capture…"
        startTask = Task { [weak self] in
            do {
                guard let self else { return }
                let firstAngle = await self.sensor.start()
                guard self.generation == run, !Task.isCancelled else { return }
                guard let angle = firstAngle else {
                    self.pause(message: "No readable lid sensor. Live effect unavailable.")
                    return
                }
                self.sensorAngle = angle
                let pixelSize = CGSize(width: screen.frame.width * screen.backingScaleFactor,
                                       height: screen.frame.height * screen.backingScaleFactor)
                try await session.start(displayID: screen.displayID, overlay: panel, pixelSize: pixelSize)
                guard self.generation == run, !Task.isCancelled else { return }
                renderer.view.frame = CGRect(origin: .zero, size: screen.frame.size)
                panel.contentView = renderer.view
                self.motion = LidMotion(angle: max(angle, self.settings.sanitized().clearAngle))
                self.lastTick = ProcessInfo.processInfo.systemUptime
                self.enabled = true
                self.busy = false
                self.lastAnglePublication = 0
                self.status = "Following your lid. Capture stays on this Mac."
                let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.tick() }
                }
                self.timer = timer
                RunLoop.main.add(timer, forMode: .common)
            } catch {
                guard let self, self.generation == run else { return }
                self.pause(message: "Could not start capture: \(error.localizedDescription)")
            }
        }
    }

    private func tick() {
        guard enabled, let renderer else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let sample = sensor.snapshot()
        guard sample.failures < 5, now - sample.time < 0.5, let angle = sample.angle else {
            pause(message: "Lid sensor stopped responding. Overlay hidden.")
            return
        }
        if now - lastAnglePublication >= 0.25 && sensorAngle != angle {
            sensorAngle = angle
            lastAnglePublication = now
        }
        let delta = min(0.1, max(0, now - lastTick))
        lastTick = now
        motion.update(target: angle, elapsed: delta)
        let state = FoldState(angle: motion.angle, settings: settings)
        renderer.state = state
        if state.isActive && renderer.hasFrame {
            if effectSince == nil { effectSince = Date() }
            if let effectSince, Date().timeIntervalSince(effectSince) > 15 {
                pause(message: "Paused after 15 seconds of continuous effect. Reopen the lid, then enable again.")
                return
            }
            if renderer.view.isPaused {
                // Render while hidden so the first visible frame already uses the current angle.
                renderer.view.draw()
                renderer.view.isPaused = false
            }
            if overlay?.isVisible == false { overlay?.orderFrontRegardless() }
        } else {
            effectSince = nil
            if overlay?.isVisible == true { overlay?.orderOut(nil) }
            renderer.view.isPaused = true
        }
    }

    func pause(message: String = "Paused. Screen capture stopped.") {
        generation += 1
        enabled = false
        timer?.invalidate()
        timer = nil
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
            await pendingStart?.value
            await previous.stop()
            await self?.sensor.stop()
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
