import Foundation
import Metal
import MetalKit
import CoreVideo
import CoreMedia
import UIKit

// MARK: - Metal Shader Uniform Structure (32-byte layout matching UltraWideShaders.metal)
public struct DistortionUniforms {
    public var zoomFactor: Float           // Offset 0 (4 bytes)
    public var distortionStrength: Float   // Offset 4 (4 bytes)
    public var k1: Float                   // Offset 8 (4 bytes)
    public var k2: Float                   // Offset 12 (4 bytes)
    public var aspectRatio: Float          // Offset 16 (4 bytes)
    public var edgeFeathering: Float       // Offset 20 (4 bytes)
    public var vignetteIntensity: Float    // Offset 24 (4 bytes)
    public var chromaticAberration: Float  // Offset 28 (4 bytes)
    
    public init(
        zoomFactor: Float,
        distortionStrength: Float,
        k1: Float,
        k2: Float,
        aspectRatio: Float,
        edgeFeathering: Float,
        vignetteIntensity: Float,
        chromaticAberration: Float
    ) {
        self.zoomFactor = zoomFactor
        self.distortionStrength = distortionStrength
        self.k1 = k1
        self.k2 = k2
        self.aspectRatio = aspectRatio
        self.edgeFeathering = edgeFeathering
        self.vignetteIntensity = vignetteIntensity
        self.chromaticAberration = chromaticAberration
    }
}

public final class MetalRenderer: NSObject, MTKViewDelegate {
    
    // MARK: - Metal Properties
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    private var vertexBuffer: MTLBuffer?
    
    // MARK: - Frame State
    private let frameLock = NSLock()
    private var currentPixelBuffer: CVPixelBuffer?
    
    // MARK: - Shader Parameters
    public var zoomFactor: Float = 1.0
    public var distortionStrength: Float = 0.45
    public var k1: Float = -0.32
    public var k2: Float = 0.12
    public var vignetteIntensity: Float = 0.35
    public var chromaticAberration: Float = 0.003
    
    // Quad Vertices for Fullscreen Pass (Clip Space & UV)
    private struct Vertex {
        var position: SIMD2<Float>
        var texCoords: SIMD2<Float>
    }
    
    private let quadVertices: [Vertex] = [
        Vertex(position: SIMD2<Float>(-1.0, -1.0), texCoords: SIMD2<Float>(0.0, 1.0)),
        Vertex(position: SIMD2<Float>( 1.0, -1.0), texCoords: SIMD2<Float>(1.0, 1.0)),
        Vertex(position: SIMD2<Float>(-1.0,  1.0), texCoords: SIMD2<Float>(0.0, 0.0)),
        
        Vertex(position: SIMD2<Float>( 1.0, -1.0), texCoords: SIMD2<Float>(1.0, 1.0)),
        Vertex(position: SIMD2<Float>( 1.0,  1.0), texCoords: SIMD2<Float>(1.0, 0.0)),
        Vertex(position: SIMD2<Float>(-1.0,  1.0), texCoords: SIMD2<Float>(0.0, 0.0))
    ]
    
    // MARK: - Initialization
    public init?(device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        super.init()
        
        setupTextureCache()
        setupPipeline()
        setupVertexBuffer()
    }
    
    private func setupTextureCache() {
        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        if status == kCVReturnSuccess {
            self.textureCache = cache
        }
    }
    
    private func setupPipeline() {
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            print("[MetalRenderer] Failed to load default Metal library.")
            return
        }
        
        let vertexFunction = defaultLibrary.makeFunction(name: "ultraWideVertexShader")
        let fragmentFunction = defaultLibrary.makeFunction(name: "ultraWideFragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "UltraCam Barrel Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("[MetalRenderer] Error creating pipeline state: \(error.localizedDescription)")
        }
    }
    
    private func setupVertexBuffer() {
        let bufferSize = MemoryLayout<Vertex>.stride * quadVertices.count
        vertexBuffer = device.makeBuffer(bytes: quadVertices, length: bufferSize, options: .storageModeShared)
    }
    
    // MARK: - Frame Ingestion
    public func updatePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        frameLock.lock()
        self.currentPixelBuffer = pixelBuffer
        frameLock.unlock()
    }
    
    // MARK: - MTKViewDelegate
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view resize if needed
    }
    
    public func draw(in view: MTKView) {
        frameLock.lock()
        guard let pixelBuffer = currentPixelBuffer else {
            frameLock.unlock()
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            frameLock.unlock()
        }
        
        guard let textureCache = self.textureCache,
              let currentDrawable = view.currentDrawable,
              let renderPassDesc = view.currentRenderPassDescriptor,
              let pipelineState = self.pipelineState else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvMetalTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvMetalTexture
        )
        
        guard status == kCVReturnSuccess,
              let cvTexture = cvMetalTexture,
              let inputTexture = CVMetalTextureGetTexture(cvTexture),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(inputTexture, index: 0)
        
        let aspect = Float(view.drawableSize.width / max(1.0, view.drawableSize.height))
        var uniforms = DistortionUniforms(
            zoomFactor: self.zoomFactor,
            distortionStrength: self.distortionStrength,
            k1: self.k1,
            k2: self.k2,
            aspectRatio: aspect,
            edgeFeathering: 0.02,
            vignetteIntensity: self.vignetteIntensity,
            chromaticAberration: self.chromaticAberration
        )
        
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DistortionUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
        encoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    // MARK: - Process Rendered Image for Photo Capture (0.5x Ultra-Wide)
    public func renderProcessedImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        
        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor),
              let textureCache = self.textureCache,
              let pipelineState = self.pipelineState else {
            return nil
        }
        
        var cvMetalTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvMetalTexture
        )
        
        guard status == kCVReturnSuccess,
              let cvTexture = cvMetalTexture,
              let inputTexture = CVMetalTextureGetTexture(cvTexture),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return nil
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(inputTexture, index: 0)
        
        var uniforms = DistortionUniforms(
            zoomFactor: self.zoomFactor,
            distortionStrength: self.distortionStrength,
            k1: self.k1,
            k2: self.k2,
            aspectRatio: Float(width) / Float(height),
            edgeFeathering: 0.02,
            vignetteIntensity: self.vignetteIntensity,
            chromaticAberration: self.chromaticAberration
        )
        
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DistortionUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Extract texture bytes to UIImage
        let rowBytes = width * 4
        var rawBytes = [UInt8](repeating: 0, count: rowBytes * height)
        let region = MTLRegionMake2D(0, 0, width, height)
        outputTexture.getBytes(&rawBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
    }
}
