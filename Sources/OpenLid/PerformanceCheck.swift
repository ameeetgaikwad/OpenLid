import AppKit
import CoreImage
import MetalKit
import FoldCore

@MainActor
enum PerformanceCheck {
    static func run() async -> Bool {
        _ = NSApplication.shared
        let sampler = SensorSampler()
        for _ in 0..<2 {
            guard await sampler.start() != nil else { print("sensor_sampler: unavailable"); return false }
            try? await Task.sleep(nanoseconds: 100_000_000)
            let sample = sampler.snapshot()
            let fresh = sample.angle != nil && sample.failures == 0 && ProcessInfo.processInfo.systemUptime - sample.time < 0.1
            await sampler.stop()
            guard fresh, sampler.snapshot().angle == nil else { print("sensor_sampler: FAIL"); return false }
        }
        print("sensor_sampler: PASS, two real-sensor start/sample/stop cycles")
        return measure()
    }

    private static func measure() -> Bool {
        let sensor = LidSensor()
        if sensor.connect() != nil {
            var times: [Double] = []
            var failures = 0
            for _ in 0..<60 {
                let start = ProcessInfo.processInfo.systemUptime
                if sensor.read() == nil { failures += 1 }
                times.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
            }
            sensor.disconnect()
            report("sensor_read", times)
            print("sensor_failures: \(failures)")
        } else { print("sensor_read: unavailable") }
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return false }
        let context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 2560, height: 1664, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return false }
        let image = PreviewArtwork.image()
        guard let pipeline = try? MetalEffectPipeline(device: device),
              let cg = context.createCGImage(image, from: image.extent),
              let source = try? MTKTextureLoader(device: device).newTexture(cgImage: cg, options: [.SRGB: false, .generateMipmaps: true]) else { return false }
        var settings = FoldSettings(); settings.style = .mist; settings.blur = 0.7; settings.clearAngle = 125
        var cpu: [Double] = [], gpu: [Double] = [], total: [Double] = []
        for index in 0..<100 {
            guard let command = queue.makeCommandBuffer() else { return false }
            let begin = ProcessInfo.processInfo.systemUptime
            let angle = 45 + 15 * sin(Double(index) * 0.07)
            guard pipeline.encode(source: source, destination: texture,
                                  state: FoldState(angle: angle, settings: settings), command: command) else { return false }
            command.commit()
            let submitted = ProcessInfo.processInfo.systemUptime
            command.waitUntilCompleted()
            guard command.status == .completed else { print("render command failed"); return false }
            if index >= 10 {
                cpu.append((submitted - begin) * 1000)
                gpu.append((command.gpuEndTime - command.gpuStartTime) * 1000)
                total.append((ProcessInfo.processInfo.systemUptime - begin) * 1000)
            }
        }
        print("fixture: generated artwork, Mist 70 percent, 2560x1664; excludes capture and WindowServer presentation")
        report("render_submit", cpu); report("render_gpu", gpu); report("render_complete", total)
        return true
    }
    private static func report(_ name: String, _ values: [Double]) {
        let sorted = values.sorted()
        print(String(format: "%@: median=%.2fms p95=%.2fms max=%.2fms", name, sorted[sorted.count / 2], sorted[Int(Double(sorted.count - 1) * 0.95)], sorted.last!))
    }
}
