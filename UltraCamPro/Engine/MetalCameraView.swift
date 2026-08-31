import SwiftUI
import MetalKit

public struct MetalCameraView: UIViewRepresentable {
    public let renderer: MetalRenderer
    
    public init(renderer: MetalRenderer) {
        self.renderer = renderer
    }
    
    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: renderer.device)
        mtkView.delegate = renderer
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtkView.contentMode = .scaleAspectFill
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        // Updated through renderer reference
    }
}
