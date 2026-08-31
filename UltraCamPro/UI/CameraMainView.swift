import SwiftUI

public struct CameraMainView: View {
    @StateObject private var cameraEngine = CameraEngine()
    @StateObject private var trackingManager = AITrackingManager()
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var cinematicEngine = CinematicEngine()
    @StateObject private var lutEngine = LUTEngine()
    
    @State private var metalRenderer: MetalRenderer?
    @State private var focusController: AIFocusController?
    
    // UI State
    @State private var showSettings: Bool = false
    @State private var showGalleryEditor: Bool = false
    @State private var showGrid: Bool = false
    @State private var showFlashAnimation: Bool = false
    @State private var manualFocusPoint: CGPoint? = nil
    @State private var showManualFocusBox: Bool = false
    
    // Pinch to Zoom gesture state
    @State private var baseZoomFactor: CGFloat = 1.0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // MARK: - LAYER 0: Viewfinder & AI Overlays
            GeometryReader { geo in
                let viewSize = geo.size
                
                ZStack {
                    // Metal Live Camera View
                    if let renderer = metalRenderer {
                        MetalCameraView(renderer: renderer)
                            .frame(width: viewSize.width, height: viewSize.height)
                            .clipped()
                    }
                    
                    // Composition 3x3 Grid Overlay
                    if showGrid {
                        CameraGridView()
                            .allowsHitTesting(false)
                    }
                    
                    // AI Neural Engine Face Tracking Boxes
                    FaceBoundingBoxOverlay(
                        faces: trackingManager.detectedFaces,
                        viewSize: viewSize
                    )
                    
                    // Manual Tap Focus Box Reticle
                    if showManualFocusBox, let point = manualFocusPoint {
                        ManualFocusReticleView()
                            .position(point)
                            .transition(.opacity)
                    }
                    
                    // White Shutter Flash Animation
                    if showFlashAnimation {
                        Color.white
                            .opacity(0.85)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
                // Tap to focus ONLY on background viewfinder
                .onTapGesture { location in
                    handleManualTapFocus(at: location, in: viewSize)
                }
                // Pinch to zoom gesture on viewfinder
                .gesture(
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
            .ignoresSafeArea()
            
            // MARK: - LAYER 1: HUD Controls Overlay (zIndex: 100 to guarantee touch priority)
            VStack(spacing: 0) {
                // Top Utility Bar with Safe Area protection
                TopBarControlsView(
                    cameraEngine: cameraEngine,
                    trackingManager: trackingManager,
                    cinematicEngine: cinematicEngine,
                    lutEngine: lutEngine,
                    onOpenSettings: { showSettings = true }
                )
                .padding(.top, 8)
                
                // Cinematic Aperture Slider (shown when Cinematic is active)
                if cinematicEngine.isCinematicEnabled {
                    HStack(spacing: 12) {
                        Text(String(format: "ƒ/%.1f", cinematicEngine.currentAperture))
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(.yellow)
                            .frame(width: 50)
                        
                        Slider(value: $cinematicEngine.currentAperture, in: 1.4...16.0, step: 0.2) { _ in
                            cinematicEngine.setAperture(cinematicEngine.currentAperture)
                            metalRenderer?.cinematicBlurRadius = cinematicEngine.blurRadius
                        }
                        .accentColor(.yellow)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 3D Film LUT Preset Selector Carousel (shown when LUT panel is open)
                if lutEngine.isLUTPanelOpen {
                    LUTSelectorView(lutEngine: lutEngine) { preset in
                        metalRenderer?.lutPresetIndex = Int32(preset.rawValue)
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Floating Zoom Dial Capsule
                ZoomDialView(
                    zoomFactor: $cameraEngine.currentZoomFactor,
                    onZoomChanged: { newZoom in
                        cameraEngine.setZoomFactor(newZoom, animated: true)
                    }
                )
                .padding(.bottom, 12)
                
                // Camera Mode Swipe Carousel
                CameraModeSelectorView(
                    selectedMode: $cameraEngine.currentMode,
                    onModeChanged: { mode in
                        handleModeChange(mode)
                    }
                )
                .padding(.bottom, 8)
                
                // Bottom Bar: Shutter, Gallery, Flip Camera
                BottomBarControlsView(
                    cameraEngine: cameraEngine,
                    onShutterTap: handleShutterTap,
                    onFlipCamera: { cameraEngine.toggleCameraPosition() },
                    onOpenGallery: { showGalleryEditor = true }
                )
            }
            .zIndex(100)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(
                cameraEngine: cameraEngine,
                trackingManager: trackingManager,
                metalRenderer: metalRenderer,
                showGrid: $showGrid
            )
        }
        .sheet(isPresented: $showGalleryEditor) {
            GalleryEditorView(initialImage: cameraEngine.lastCapturedThumbnail)
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
        
        cinematicEngine.onMaskGenerated = { [weak metalRenderer] maskBuffer in
            metalRenderer?.updateMaskBuffer(maskBuffer)
        }
        
        cameraEngine.onFrameReceived = { [weak trackingManager, weak cinematicEngine] pixelBuffer in
            trackingManager?.processFrame(pixelBuffer)
            if cinematicEngine?.isCinematicEnabled == true {
                cinematicEngine?.processFrame(pixelBuffer)
            }
        }
        
        cameraEngine.requestPermissionsAndConfigure { granted in
            if !granted {
                print("[CameraMainView] Camera/Microphone access not granted.")
            }
        }
    }
    
    // MARK: - Mode Change Handler with Clean State Reset
    private func handleModeChange(_ mode: CameraMode) {
        switch mode {
        case .photo:
            cinematicEngine.isCinematicEnabled = false
            cameraEngine.isProRAWEnabled = false
            metalRenderer?.resetCinematicState()
        case .video:
            cinematicEngine.isCinematicEnabled = false
            metalRenderer?.resetCinematicState()
        case .cinematic:
            cinematicEngine.isCinematicEnabled = true
            cinematicEngine.setAperture(2.8)
            metalRenderer?.cinematicBlurRadius = cinematicEngine.blurRadius
        case .portrait:
            cinematicEngine.isCinematicEnabled = true
            cinematicEngine.setAperture(2.0)
            metalRenderer?.cinematicBlurRadius = cinematicEngine.blurRadius
        case .proRaw:
            cameraEngine.isProRAWEnabled = true
            cinematicEngine.isCinematicEnabled = false
            metalRenderer?.resetCinematicState()
        }
    }
    
    // MARK: - Shutter Action & Animation
    private func handleShutterTap() {
        withAnimation(.easeOut(duration: 0.10)) {
            showFlashAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeIn(duration: 0.12)) {
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
            .stroke(Color.white.opacity(0.25), lineWidth: 0.75)
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
                .frame(width: 68, height: 68)
            
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
