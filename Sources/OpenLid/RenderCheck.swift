import AppKit
import CoreImage
import MetalKit
import FoldCore

@MainActor
enum RenderCheck {
    static func run() -> Bool {
        _ = NSApplication.shared
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("render_check: FAIL, Metal unavailable")
            return false
        }
        let context = CIContext(mtlDevice: device)
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 200)
        let input = CIImage(color: CIColor(red: 0.7, green: 0.7, blue: 0.7)).cropped(to: bounds)
        let artworkImage = PreviewArtwork.image()
        guard let pipeline = try? MetalEffectPipeline(device: device), let queue = device.makeCommandQueue(),
              let cg = context.createCGImage(input, from: bounds),
              let source = try? MTKTextureLoader(device: device).newTexture(cgImage: cg, options: [.SRGB: false, .generateMipmaps: true]),
              let artworkCG = context.createCGImage(artworkImage, from: artworkImage.extent),
              let artwork = try? MTKTextureLoader(device: device).newTexture(cgImage: artworkCG, options: [.SRGB: false, .generateMipmaps: true]) else { return false }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 320, height: 200, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let destination = device.makeTexture(descriptor: descriptor) else { return false }
        func render(_ source: MTLTexture, _ state: FoldState) -> [UInt8]? {
            guard let command = queue.makeCommandBuffer(),
                  pipeline.encode(source: source, destination: destination, state: state, command: command) else { return nil }
            command.commit(); command.waitUntilCompleted()
            guard command.status == .completed else { return nil }
            var bytes = [UInt8](repeating: 0, count: 320 * 200 * 4)
            destination.getBytes(&bytes, bytesPerRow: 320 * 4, from: MTLRegionMake2D(0, 0, 320, 200), mipmapLevel: 0)
            return bytes
        }
        func snapshot(_ bytes: [UInt8]) -> CGImage? {
            guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
            return CGImage(width: 320, height: 200, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1280,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                           provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
        var passed = true
        var checks = 0
        var snapshots: [(String, CGImage)] = []
        for style in FoldStyle.allCases {
            var settings = FoldSettings(); settings.style = style
            for angle in [120.0, 85, 60, 35, 0] {
                let state = FoldState(angle: angle, settings: settings)
                guard let bytes = render(source, state) else { return false }
                var valid = true
                for offset in stride(from: 0, to: bytes.count, by: 4) {
                    let red = Int(bytes[offset]), green = Int(bytes[offset + 1]), blue = Int(bytes[offset + 2])
                    if bytes[offset + 3] != 255 || red <= 40 || abs(red - green) > 1 || abs(red - blue) > 1 {
                        valid = false
                        break
                    }
                }
                if state.darkness > 0.02 {
                    // Bitmap rows are top-to-bottom; the upper edge should be darker.
                    valid = valid && bytes[0] < bytes[(320 * 199) * 4]
                }
                if !valid { print("FAIL coverage/color: \(style.rawValue), \(angle)") }
                passed = passed && valid; checks += 1
                if angle > 0 {
                    if let bytes = render(artwork, state), let cg = snapshot(bytes) {
                        snapshots.append(("\(style.rawValue)  \(Int(angle)) degrees", cg))
                    } else { passed = false }
                }
            }
            settings.perspective = 0; settings.blur = 0; settings.shade = 0
            guard let closed = render(source, FoldState(angle: 0, settings: settings)),
                  let open = render(source, FoldState(angle: 180, settings: settings)) else { return false }
            passed = passed && closed == open
            checks += 1
        }
        // Compare the optimized warp against the original graph using structured artwork.
        for angle in [120.0, 60, 35] {
            var settings = FoldSettings(); settings.blur = 0; settings.shade = 0
            let state = FoldState(angle: angle, settings: settings)
            guard let actual = render(artwork, state) else { return false }
            let reference = FoldRenderer.transformedImage(artworkImage, bounds: bounds, state: state)
            var expected = [UInt8](repeating: 0, count: 320 * 200 * 4)
            expected.withUnsafeMutableBytes {
                context.render(reference, toBitmap: $0.baseAddress!, rowBytes: 1280, bounds: bounds,
                               format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            }
            var difference = 0
            for offset in stride(from: 0, to: actual.count, by: 4) {
                difference += abs(Int(actual[offset]) - Int(expected[offset + 2]))
                difference += abs(Int(actual[offset + 1]) - Int(expected[offset + 1]))
                difference += abs(Int(actual[offset + 2]) - Int(expected[offset]))
            }
            let mean = Double(difference) / Double(320 * 200 * 3)
            if mean > 2 { passed = false; print("FAIL reference geometry, angle \(angle), mean byte error \(mean)") }
            checks += 1
        }
        let sheet = NSImage(size: NSSize(width: 1280, height: 720), flipped: false) { rect in
            NSColor(white: 0.96, alpha: 1).setFill(); rect.fill()
            for (index, snapshot) in snapshots.enumerated() {
                let x = (index % 4) * 320, y = 720 - (index / 4 + 1) * 240
                NSImage(cgImage: snapshot.1, size: bounds.size).draw(in: NSRect(x: x, y: y, width: 320, height: 200))
                (snapshot.0 as NSString).draw(at: NSPoint(x: x + 12, y: y + 212), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.black
                ])
            }
            return true
        }
        if let tiff = sheet.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            do { try png.write(to: URL(fileURLWithPath: "/tmp/openlid-neutral-render-check.png")) }
            catch { passed = false; print("FAIL writing generated preview: \(error)") }
        } else { passed = false }
        print("render_check: \(passed ? "PASS" : "FAIL"), \(checks) pixel checks, generated artwork only, Metal \(device.name)")
        print("generated_preview: /tmp/openlid-neutral-render-check.png")
        return passed
    }
}
