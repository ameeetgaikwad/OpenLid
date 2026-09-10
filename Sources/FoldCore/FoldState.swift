import Foundation

public enum FoldStyle: String, CaseIterable, Codable, Identifiable {
    case paper = "Paper", dusk = "Dusk", mist = "Mist"
    public var id: String { rawValue }
}

public struct FoldSettings: Codable, Equatable {
    public var style: FoldStyle = .paper
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
    public var isActive: Bool { progress > 0.005 }

    public init(angle: Double, settings: FoldSettings) {
        let s = settings.sanitized()
        let angle = FoldSettings.clamp(angle, 0...180, fallback: 180)
        let linear = max(0, min(1, 1 - angle / s.clearAngle))
        progress = linear * linear * (3 - 2 * linear)
        inset = progress * s.perspective * 0.24
        height = max(0.08, 1 - progress * (0.6 + s.perspective * 0.3))
        blurRadius = progress * s.blur * (s.style == .mist ? 36 : 12)
        darkness = min(0.85, progress * s.shade * (s.style == .dusk ? 1.4 : 0.65))
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
