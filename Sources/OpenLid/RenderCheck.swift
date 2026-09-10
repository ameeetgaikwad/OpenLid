import CoreImage
import Metal
import FoldCore

enum RenderCheck {
    /// Exercises the production filter graph with generated pixels, never a captured screen.
    static func run() -> Bool {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("render_check: unavailable — no Metal device")
            return false
        }
        let context = CIContext(mtlDevice: device)
        let bounds = CGRect(x: 0, y: 0, width: 160, height: 100)
        let input = CIImage(color: CIColor(red: 0.8, green: 0.6, blue: 0.4)).cropped(to: bounds)
        var sums: [Int] = []
        for angle in [120.0, 35.0] {
            let output = FoldRenderer.transformedImage(input, bounds: bounds, state: FoldState(angle: angle, settings: FoldSettings()))
            var pixels = [UInt8](repeating: 0, count: 160 * 100 * 4)
            pixels.withUnsafeMutableBytes { buffer in
                context.render(output, toBitmap: buffer.baseAddress!, rowBytes: 160 * 4,
                               bounds: bounds, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            }
            sums.append(stride(from: 0, to: pixels.count, by: 4).reduce(0) { $0 + Int(pixels[$1]) })
        }
        let passed = sums[0] > 0 && sums[1] > 0 && sums[1] < sums[0]
        print("render_check: \(passed ? "PASS" : "FAIL") — Metal \(device.name), open_sum=\(sums[0]), folded_sum=\(sums[1]), generated pixels only")
        return passed
    }
}
