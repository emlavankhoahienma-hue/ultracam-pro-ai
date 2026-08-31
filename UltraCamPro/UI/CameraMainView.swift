import SwiftUI

public struct CameraMainView: View {
    @StateObject private var cameraEngine = CameraEngine()
    @StateObject private var trackingManager = AITrackingManager()
    @StateObject private var orientationManager = OrientationManager()
    
    @State private var metalRenderer: MetalRenderer?
    @State private var focusController: AIFocusController?
    
    // UI State
    @State private var showSettings: Bool = false
    @State private var showGrid: Bool = false
    @State private var showFlashAnimation: Bool = false
    @State private var manualFocusPoint: CGPoint? = nil
    @State private var showManualFocusBox: Bool = false
    
    // Pinch to Zoom gesture state
    @State private var baseZoomFactor: CGFloat = 1.0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            GeometryReader { geo in
                let viewSize = geo.size
                
                ZStack {
                    // MARK: - Metal Viewfinder Live Feed
                    if let renderer = metalRenderer {
                        MetalCameraView(renderer: renderer)
                            .frame(width: viewSize.width, height: viewSize.height)
                            .clipped()
                    }
                    
                    // MARK: - Composition 3x3 Grid
                    if showGrid {
                        CameraGridView()
                            .allowsHitTesting(false)
                    }
                    
                    // MARK: - AI Neural Engine Face Tracking Overlay
                    FaceBoundingBoxOverlay(
                        faces: trackingManager.detectedFaces,
                        viewSize: viewSize
                    )
                    
                    // MARK: - Manual Tap Focus Box Reticle
                    if showManualFocusBox, let point = manualFocusPoint {
                        ManualFocusReticleView()
                            .position(point)
                            .transition(.opacity)
                    }
                    
                    // MARK: - White Shutter Flash Effect
                    if showFlashAnimation {
                        Color.white
                            .opacity(0.85)
                            .edgesIgnoringSafeArea(.all)
                            .transition(.opacity)
                    }
                    
                    // MARK: - HUD Controls Overlay
                    VStack(spacing: 0) {
                        // Top Bar
                        TopBarControlsView(
                            cameraEngine: cameraEngine,
                            trackingManager: trackingManager,
                            onOpenSettings: { showSettings = true }
                        )
                        .padding(.top, geo.safeAreaInsets.top)
                        
                        Spacer()
                        
                        // Zoom Dial & Buttons
                        ZoomDialView(
                            zoomFactor: $cameraEngine.currentZoomFactor,
                            onZoomChanged: { newZoom in
                                cameraEngine.setZoomFactor(newZoom, animated: true)
                            }
                        )
                        .padding(.bottom, 16)
                        
                        // Bottom Bar
                        BottomBarControlsView(
                            cameraEngine: cameraEngine,
                            onShutterTap: handleShutterTap,
                            onFlipCamera: { cameraEngine.toggleCameraPosition() },
                            onOpenGallery: { /* Opens system photo library */ }
                        )
                    }
                }
                .contentShape(Rectangle())
                // MARK: - Gestures: Tap to Focus & Pinch to Zoom
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            // Handled by spatial tap
                        }
                )
                .highPriorityGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleManualTapFocus(at: value.location, in: viewSize)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            let targetZoom = max(0.5, min(5.0, baseZoomFactor * scale))
                            cameraEngine.setZoomFactor(targetZoom, animated: false)
                        }
                        .onEnded { _ in
                            baseZoomFactor = cameraEngine.currentZoomFactor
                        }
                )
            }
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(
                cameraEngine: cameraEngine,
                trackingManager: trackingManager,
                metalRenderer: metalRenderer,
                showGrid: $showGrid
            )
        }
        .onAppear {
            initializeCameraPipeline()
        }
    }
    
    // MARK: - Pipeline Initialization
    private func initializeCameraPipeline() {
        guard metalRenderer == nil else { return }
        
        if let renderer = MetalRenderer() {
            self.metalRenderer = renderer
            self.cameraEngine.metalRenderer = renderer
        }
        
        let focus = AIFocusController(cameraEngine: cameraEngine, trackingManager: trackingManager)
        self.focusController = focus
        
        cameraEngine.onFrameReceived = { [weak trackingManager] pixelBuffer in
            trackingManager?.processFrame(pixelBuffer)
        }
        
        cameraEngine.requestPermissionsAndConfigure { granted in
            if !granted {
                print("[CameraMainView] Camera/Microphone access not granted.")
            }
        }
    }
    
    // MARK: - Shutter Action & Animation
    private func handleShutterTap() {
        withAnimation(.easeOut(duration: 0.12)) {
            showFlashAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.15)) {
                showFlashAnimation = false
            }
        }
        cameraEngine.capturePhoto()
    }
    
    // MARK: - Manual Tap to Focus
    private func handleManualTapFocus(at point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        
        HapticManager.shared.triggerLightTap()
        manualFocusPoint = point
        showManualFocusBox = true
        
        let normalizedPoint = CGPoint(x: point.y / size.height, y: 1.0 - (point.x / size.width))
        cameraEngine.applyAIFocus(at: normalizedPoint)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showManualFocusBox = false
            }
        }
    }
}

// MARK: - Camera 3x3 Composition Grid View
public struct CameraGridView: View {
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            Path { path in
                // Vertical lines
                path.move(to: CGPoint(x: w / 3.0, y: 0))
                path.addLine(to: CGPoint(x: w / 3.0, y: h))
                path.move(to: CGPoint(x: 2 * w / 3.0, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3.0, y: h))
                
                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: h / 3.0))
                path.addLine(to: CGPoint(x: w, y: h / 3.0))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3.0))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3.0))
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.75)
        }
    }
}

// MARK: - Manual Focus Box Reticle View
public struct ManualFocusReticleView: View {
    @State private var scale: CGFloat = 1.3
    
    public var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 70, height: 70)
            
            Circle()
                .fill(Color.yellow)
                .frame(width: 4, height: 4)
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }
    }
}
