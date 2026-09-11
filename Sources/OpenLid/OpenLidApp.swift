import AppKit
import SwiftUI

@main
struct OpenLidApp {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--performance-check") {
            Task { @MainActor in exit(await PerformanceCheck.run() ? 0 : 1) }
            RunLoop.main.run()
            return
        }
        if CommandLine.arguments.contains("--render-check") {
            exit(RenderCheck.run() ? 0 : 1)
        }
        if CommandLine.arguments.contains("--diagnostics") {
            let sensor = LidSensor()
            if let angle = sensor.connect() { print("lid_angle_degrees: \(angle)") }
            else { print("unsupported: No readable Apple orientation HID sensor (05ac:8104, usage 20:8a). Manual preview available.") }
            print("renderer: metal_capture")
            print("screen_capture_permission: \(CGPreflightScreenCaptureAccess() ? "granted" : "not_granted")")
            print("screen_capture_started: false")
            print("macos: \(ProcessInfo.processInfo.operatingSystemVersionString)")
            sensor.disconnect()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var toggleItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        // Window key equivalents are dispatched through the application menu,
        // not the status item's popup menu.
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "OpenLid")
        let applicationQuit = NSMenuItem(title: "Quit OpenLid", action: #selector(quitApp), keyEquivalent: "q")
        applicationQuit.keyEquivalentModifierMask = [.command]
        applicationQuit.target = self
        applicationMenu.addItem(applicationQuit)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "OpenLid")
        statusItem.button?.toolTip = "OpenLid: neutral lid effects"
        let menu = NSMenu()
        menu.delegate = self
        let settings = NSMenuItem(title: "Open OpenLid…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        toggleItem = NSMenuItem(title: "Enable live effect", action: #selector(toggleEffect), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit OpenLid", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 680),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "OpenLid"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        showSettings()
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem.title = model.enabled ? "Pause live effect" : "Enable live effect"
        toggleItem.isEnabled = !model.busy
    }

    @objc private func showSettings() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleEffect() {
        if model.enabled { model.pause() } else { model.enable() }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.pause()
    }
}
