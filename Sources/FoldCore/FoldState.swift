import Foundation

public enum FoldStyle: String, CaseIterable, Codable, Identifiable {
    case paper = "Paper", dusk = "Dusk", mist = "Mist"
    public var id: String { rawValue }
}

public struct FoldSettings: Codable, Equatable {
    public var style: FoldStyle = .mist
    public var perspective: Double = 0.65
    public var blur: Double = 0.35
    public var shade: Double = 0.45
    public var clearAngle: Double = 100
    public init() {}

    public func sanitized() -> Self {
        var result = self
        result.perspective = Self.clamp(perspective, 0...1, fallback: 0.65)
        result.blur = Self.clamp(blur, 0...1, fallback: 0.35)
        result.shade = Self.clamp(shade, 0...1, fallback: 0.45)
        result.clearAngle = Self.clamp(clearAngle, 45...140, fallback: 100)
        return result
    }

    static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}

public struct FoldState: Equatable {
    public let progress: Double
    public let inset: Double
    public let height: Double
    public let blurRadius: Double
    public let darkness: Double
    public var isActive: Bool { progress > 0.001 }

    public init(angle: Double, settings: FoldSettings) {
        let s = settings.sanitized()
        let angle = FoldSettings.clamp(angle, 0...180, fallback: 180)
        let linear = max(0, min(1, 1 - angle / s.clearAngle))
        progress = linear * linear * (3 - 2 * linear)
        // Expand toward the viewer to counter foreshortening, never collapse into a black gap.
        // This bounded model is tunable, not a claim of calibrated eye tracking.
        let rotation = progress * Double.pi / 3
        height = 1 + (1 / cos(rotation) - 1) * s.perspective
        inset = sin(rotation) * s.perspective * 0.18
        let softening = progress * progress
        switch s.style {
        case .paper:
            blurRadius = softening * s.blur * 10
            darkness = progress * s.shade * 0.20
        case .dusk:
            blurRadius = softening * s.blur * 12
            darkness = progress * s.shade * 0.65
        case .mist:
            blurRadius = softening * s.blur * 28
            darkness = progress * s.shade * 0.12
        }
    }
}

public struct LidMotion {
    public private(set) var angle: Double
    public init(angle: Double) { self.angle = FoldSettings.clamp(angle, 0...180, fallback: 180) }
    public mutating func update(target: Double, elapsed: Double) {
        let target = FoldSettings.clamp(target, 0...180, fallback: 180)
        let elapsed = FoldSettings.clamp(elapsed, 0...0.1, fallback: 0)
        let response = target > angle ? 0.055 : 0.10
        angle += (target - angle) * (1 - exp(-elapsed / response))
        if abs(angle - target) < 0.05 { angle = target }
    }
}

public enum LidReport {
    /// Apple orientation sensor, feature report 1: little-endian integer degrees.
    public static func angle(from bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let degrees = Int(bytes[1]) | Int(bytes[2]) << 8
        guard (0...180).contains(degrees) else { return nil }
        return Double(degrees)
    }
}
