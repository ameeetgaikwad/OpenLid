import MetalKit
import MetalPerformanceShaders
import FoldCore

/// Pipelines are compiled once; live frames are bound directly as Metal textures.
final class MetalEffectPipeline {
    let device: MTLDevice
    private let warp: MTLComputePipelineState
    private let finish: MTLComputePipelineState
    private var intermediate: MTLTexture?
    private var blurred: MTLTexture?
    private var blurKernels: [Int: MPSImageGaussianBlur] = [:]

    init(device: MTLDevice) throws {
        self.device = device
        let library = try device.makeLibrary(source: Self.source, options: nil)
        warp = try device.makeComputePipelineState(function: library.makeFunction(name: "warpDesktop")!)
        finish = try device.makeComputePipelineState(function: library.makeFunction(name: "finishDesktop")!)
    }

    func encode(source: MTLTexture, destination: MTLTexture, state: FoldState, command: MTLCommandBuffer) -> Bool {
        let radius = Float(state.blurRadius) * Float(destination.width) / 1440
        var params = SIMD4<Float>(Float(state.inset), Float(state.height), radius, Float(state.darkness))
        if radius < 0.125 {
            params.z = 0
            return dispatch(warp, source: source, destination: destination, params: params, command: command)
        }
        if intermediate?.width != destination.width || intermediate?.height != destination.height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: destination.width, height: destination.height, mipmapped: false)
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            intermediate = device.makeTexture(descriptor: descriptor)
            blurred = device.makeTexture(descriptor: descriptor)
        }
        guard let intermediate, let blurred,
              dispatch(warp, source: source, destination: intermediate, params: params, command: command) else { return false }
        // Quarter-pixel sigma steps keep kernel allocation out of steady-state frames.
        let key = max(1, Int((radius * 4).rounded()))
        let blur: MPSImageGaussianBlur
        if let cached = blurKernels[key] { blur = cached }
        else {
            blur = MPSImageGaussianBlur(device: device, sigma: Float(key) / 4)
            blur.edgeMode = .clamp
            blurKernels[key] = blur
        }
        blur.encode(commandBuffer: command, sourceTexture: intermediate, destinationTexture: blurred)
        return dispatch(finish, source: blurred, destination: destination, params: params, command: command)
    }

    private func dispatch(_ pipeline: MTLComputePipelineState, source: MTLTexture, destination: MTLTexture,
                          params: SIMD4<Float>, command: MTLCommandBuffer) -> Bool {
        guard let encoder = command.makeComputeCommandEncoder() else { return false }
        var params = params
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        let width = pipeline.threadExecutionWidth
        let height = max(1, min(8, pipeline.maxTotalThreadsPerThreadgroup / width))
        encoder.dispatchThreads(MTLSize(width: destination.width, height: destination.height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: width, height: height, depth: 1))
        encoder.endEncoding()
        return true
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    float3 toLinear(float3 c) {
        return select(c / 12.92, pow((c + 0.055) / 1.055, float3(2.4)), c > 0.04045);
    }
    float3 toSRGB(float3 c) {
        c = max(c, float3(0.0));
        return select(c * 12.92, 1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, c > 0.0031308);
    }
    float4 shade(float4 color, float yFromTop, float darkness) {
        float opacity = darkness * mix(1.0, 0.25, yFromTop);
        return float4(toSRGB(color.rgb * (1.0 - opacity)), 1.0);
    }
    kernel void warpDesktop(texture2d<float, access::sample> source [[texture(0)]],
                            texture2d<float, access::write> output [[texture(1)]],
                            constant float4& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
        float2 uv = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
        float q = 2.0 * p.x / (1.0 + 2.0 * p.x);
        float y = 1.0 - uv.y;
        float sourceY = y / (p.y * (1.0 - q) + q * y);
        float2 sampleUV = float2((uv.x - 0.5) * (1.0 - q * sourceY) + 0.5, 1.0 - sourceY);
        constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
        float ratio = max(float(source.get_width()) / output.get_width(), float(source.get_height()) / output.get_height());
        float lod = max(0.0, log2(ratio));
        float4 color = float4(toLinear(source.sample(linearSampler, sampleUV, level(lod)).rgb), 1.0);
        output.write(p.z == 0.0 ? shade(color, uv.y, p.w) : color, gid);
    }
    kernel void finishDesktop(texture2d<float, access::read> source [[texture(0)]],
                              texture2d<float, access::write> output [[texture(1)]],
                              constant float4& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
        float y = (float(gid.y) + 0.5) / float(output.get_height());
        output.write(shade(source.read(gid), y, p.w), gid);
    }
    """
}
