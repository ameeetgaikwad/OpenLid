import Foundation

/// All blocking HID operations share a background queue; animation reads only a cached sample.
// Sensor and timer are queue-confined; the only cross-thread value is protected by lock.
final class SensorSampler: @unchecked Sendable {
    private let queue = DispatchQueue(label: "org.openlid.sensor", qos: .userInteractive)
    private let sensor = LidSensor()
    private var timer: DispatchSourceTimer?
    private let lock = NSLock()
    private var latest: (angle: Double?, failures: Int, time: TimeInterval) = (nil, 0, 0)

    func snapshot() -> (angle: Double?, failures: Int, time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        return latest
    }

    func probe() async -> Double? {
        await withCheckedContinuation { continuation in
            queue.async {
                let sensor = LidSensor()
                let angle = sensor.connect()
                sensor.disconnect()
                continuation.resume(returning: angle)
            }
        }
    }

    func start() async -> Double? {
        await withCheckedContinuation { continuation in
            queue.async {
                let angle = self.sensor.connect()
                self.lock.lock()
                self.latest = (angle, 0, ProcessInfo.processInfo.systemUptime)
                self.lock.unlock()
                if angle != nil {
                    let timer = DispatchSource.makeTimerSource(queue: self.queue)
                    timer.schedule(deadline: .now(), repeating: 1.0 / 60, leeway: .milliseconds(1))
                    timer.setEventHandler { [weak self] in self?.sample() }
                    self.timer = timer
                    timer.resume()
                }
                continuation.resume(returning: angle)
            }
        }
    }

    private func sample() {
        let angle = sensor.read()
        lock.lock()
        if let angle { latest = (angle, 0, ProcessInfo.processInfo.systemUptime) }
        else { latest.failures += 1 }
        lock.unlock()
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.timer?.cancel()
                self.timer = nil
                self.sensor.disconnect()
                self.lock.lock(); self.latest = (nil, 0, 0); self.lock.unlock()
                continuation.resume()
            }
        }
    }
}
