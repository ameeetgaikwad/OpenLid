import Foundation
import FoldCore

// No XCTest dependency: these checks also run with Command Line Tools alone.
private var assertions = 0
private var failures = 0
private func expect(_ condition: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    assertions += 1
    if !condition {
        failures += 1
        print("FAIL \(file):\(line) \(message)")
    }
}
private func XCTAssertNil<T>(_ value: T?, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    expect(value == nil, message, file: file, line: line)
}
private func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) {
    expect(lhs == rhs, "\(lhs) != \(rhs)", file: file, line: line)
}
private func XCTAssertTrue(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    expect(condition, file: file, line: line)
}
private func XCTAssertFalse(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    expect(!condition, file: file, line: line)
}
private func XCTAssertGreaterThanOrEqual(_ lhs: Double, _ rhs: Double, file: StaticString = #filePath, line: UInt = #line) {
    expect(lhs >= rhs, file: file, line: line)
}
private func XCTAssertGreaterThan(_ lhs: Double, _ rhs: Double, file: StaticString = #filePath, line: UInt = #line) {
    expect(lhs > rhs, file: file, line: line)
}

@main
struct FoldCoreTests {
    static func main() {
        let suite = Self()
        suite.testSensorReportsRejectMalformedAndOutOfRangeData()
        suite.testOpenLidAlwaysClearsEffect()
        suite.testClosingMotionIsMonotonicAndBounded()
        suite.testCorruptPreferencesAreSanitized()
        suite.testStylesChangeTheIntendedDimension()
        suite.testZeroIntensityDisablesBlurAndShadow()
        suite.testMotionSmoothing()
        suite.testProjectionNeverShrinks()
        print("\(failures == 0 ? "PASS" : "FAIL"): 8 checks, \(assertions) assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
    func testSensorReportsRejectMalformedAndOutOfRangeData() {
        let reports: [[UInt8]] = [[], [1], [1, 90], [0, 90, 0], [2, 90, 0], [1, 181, 0], [1, 0, 1], [1, 255, 255]]
        for bytes in reports {
            XCTAssertNil(LidReport.angle(from: bytes), "Accepted malformed report \(bytes)")
        }
        XCTAssertEqual(LidReport.angle(from: [1, 0, 0]), 0)
        XCTAssertEqual(LidReport.angle(from: [1, 90, 0]), 90)
        XCTAssertEqual(LidReport.angle(from: [1, 180, 0, 0, 0]), 180)
    }

    func testOpenLidAlwaysClearsEffect() {
        for clear in [45.0, 100, 140] {
            var settings = FoldSettings()
            settings.clearAngle = clear
            for angle in [clear, clear + 1, 180, 1000, .infinity, .nan] {
                let state = FoldState(angle: angle, settings: settings)
                XCTAssertFalse(state.isActive)
                XCTAssertEqual(state.height, 1)
                XCTAssertEqual(state.blurRadius, 0)
                XCTAssertEqual(state.darkness, 0)
            }
        }
    }

    func testClosingMotionIsMonotonicAndBounded() {
        var previous = 0.0
        for angle in stride(from: 180.0, through: 0, by: -1) {
            let state = FoldState(angle: angle, settings: FoldSettings())
            XCTAssertGreaterThanOrEqual(state.progress, previous)
            XCTAssertTrue((0...1).contains(state.progress))
            XCTAssertTrue((1...2.000001).contains(state.height))
            XCTAssertTrue((0...0.24).contains(state.inset))
            XCTAssertTrue((0...0.85).contains(state.darkness))
            previous = state.progress
        }
        XCTAssertEqual(previous, 1)
    }

    func testCorruptPreferencesAreSanitized() {
        var settings = FoldSettings()
        settings.clearAngle = 0
        settings.perspective = .infinity
        settings.blur = -.infinity
        settings.shade = .nan
        let state = FoldState(angle: -5, settings: settings)
        XCTAssertEqual(state.progress, 1)
        XCTAssertTrue(state.height.isFinite)
        XCTAssertTrue(state.blurRadius.isFinite)
        XCTAssertTrue(state.darkness.isFinite)
        XCTAssertEqual(settings.sanitized().clearAngle, 45)
    }

    func testStylesChangeTheIntendedDimension() {
        var settings = FoldSettings()
        XCTAssertEqual(settings.style, .mist)
        settings.style = .paper
        let paper = FoldState(angle: 35, settings: settings)
        settings.style = .dusk
        let dusk = FoldState(angle: 35, settings: settings)
        settings.style = .mist
        let mist = FoldState(angle: 35, settings: settings)
        XCTAssertGreaterThan(dusk.darkness, paper.darkness)
        XCTAssertGreaterThan(mist.blurRadius, paper.blurRadius)
        XCTAssertEqual(dusk.inset, paper.inset)
        XCTAssertEqual(mist.height, paper.height)
    }

    func testZeroIntensityDisablesBlurAndShadow() {
        var settings = FoldSettings()
        settings.blur = 0
        settings.shade = 0
        settings.perspective = 0
        for style in FoldStyle.allCases {
            settings.style = style
            let state = FoldState(angle: 0, settings: settings)
            XCTAssertEqual(state.blurRadius, 0)
            XCTAssertEqual(state.darkness, 0)
            XCTAssertEqual(state.inset, 0)
        }
    }

    func testProjectionNeverShrinks() {
        for style in FoldStyle.allCases {
            for strength in [0.0, 0.5, 1.0] {
                var settings = FoldSettings(); settings.style = style; settings.perspective = strength
                var previousHeight = 1.0
                for angle in stride(from: 100.0, through: 0, by: -1) {
                    let state = FoldState(angle: angle, settings: settings)
                    XCTAssertGreaterThanOrEqual(state.height, previousHeight)
                    XCTAssertGreaterThanOrEqual(state.height, 1)
                    XCTAssertGreaterThanOrEqual(state.inset, 0)
                    if strength == 0 { XCTAssertEqual(state.height, 1); XCTAssertEqual(state.inset, 0) }
                    previousHeight = state.height
                }
            }
        }
    }

    func testMotionSmoothing() {
        var a = LidMotion(angle: 100), b = LidMotion(angle: 100)
        for _ in 0..<30 { a.update(target: 30, elapsed: 1.0 / 30) }
        for _ in 0..<60 { b.update(target: 30, elapsed: 1.0 / 60) }
        XCTAssertTrue(abs(a.angle - b.angle) < 0.001)
        var previous = b.angle
        for _ in 0..<60 {
            b.update(target: 120, elapsed: 1.0 / 60)
            XCTAssertGreaterThanOrEqual(b.angle, previous)
            XCTAssertTrue(b.angle <= 120)
            previous = b.angle
        }
        XCTAssertEqual(b.angle, 120)
    }

}
