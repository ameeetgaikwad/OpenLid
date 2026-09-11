import Foundation
import IOKit.hid
import FoldCore

/// Read-only feature reports. This implementation polls at 60 Hz only while enabled.
/// The HID interface is undocumented by Apple and is not available on every MacBook.
final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?

    func connect() -> Double? {
        disconnect()
        var connected = false
        defer { if !connected { disconnect() } }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        let matching: [String: Int] = [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDDeviceUsagePageKey: 0x0020,
            kIOHIDDeviceUsageKey: 0x008A
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard IOHIDManagerOpen(manager, 0) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return nil }
        for candidate in devices {
            guard IOHIDDeviceOpen(candidate, 0) == kIOReturnSuccess else { continue }
            device = candidate
            if let angle = read() {
                connected = true
                return angle
            }
            IOHIDDeviceClose(candidate, 0)
            device = nil
        }
        return nil
    }

    func read() -> Double? {
        guard let device else { return nil }
        var bytes = [UInt8](repeating: 0, count: 8)
        var length = bytes.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &length)
        guard result == kIOReturnSuccess, length <= bytes.count else { return nil }
        return LidReport.angle(from: Array(bytes.prefix(length)))
    }

    func disconnect() {
        if let device { IOHIDDeviceClose(device, 0) }
        if let manager { IOHIDManagerClose(manager, 0) }
        device = nil
        manager = nil
    }

    deinit { disconnect() }
}
