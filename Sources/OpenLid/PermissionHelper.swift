import AppKit
import SwiftUI

@MainActor
final class PermissionHelper {
    private var panel: NSPanel?

    func show(model: AppModel) {
        if let panel {
            model.refreshPermission()
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 490),
                            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = "Enable OpenLid"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PermissionHelperView(model: model) { [weak panel] in
            panel?.orderOut(nil)
        })
        if let screen = NSScreen.main {
            let area = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 20,
                                         y: max(area.minY, area.midY - panel.frame.height / 2)))
        }
        self.panel = panel
        model.refreshPermission()
        panel.makeKeyAndOrderFront(nil)
    }
}

private struct PermissionHelperView: View {
    @ObservedObject var model: AppModel
    let close: () -> Void
    private let appURL = Bundle.main.bundleURL

    var body: some View {
        VStack(spacing: 17) {
            Text("One small permission.")
                .font(.system(size: 23, weight: .medium, design: .serif))
            Text("Keep this window beside System Settings.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            VStack(spacing: 9) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable().interpolation(.high).frame(width: 64, height: 64)
                Text("OpenLid.app").font(.system(size: 14, weight: .semibold))
                Label("Drag into the permission list", systemImage: "hand.draw")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(17)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
            .contentShape(Rectangle())
            .onDrag { NSItemProvider(object: appURL as NSURL) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("OpenLid application. Drag to System Settings permission list.")
            Text("Already listed? Switch OpenLid on.\nCan't drop? Use + to add the app.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Button("Show OpenLid in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([appURL])
            }
            HStack(spacing: 7) {
                Image(systemName: model.permissionGranted ? "checkmark.circle.fill" : "lock.circle")
                    .foregroundStyle(model.permissionGranted ? Color.green : Color.secondary)
                Text(model.permissionGranted ? "Permission detected. You can enable the effect." : "Enable access, then quit and reopen OpenLid if asked.")
                    .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Check permission") { model.refreshPermission() }
                Spacer()
                Button("Done", action: close).keyboardShortcut(.defaultAction)
            }
            Text("Frames stay on your Mac. You control access.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(22).frame(width: 320, height: 490)
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .preferredColorScheme(.light)
    }
}
