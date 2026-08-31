import SwiftUI
import AVFoundation

public struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var faceTrackingEngine: FaceTrackingEngine?
    
    // UI State
    @State private var manualFocusPoint: CGPoint? = nil
    @State private var showFocusBox: Bool = false
    @State private var showFlashAnimation: Bool = false
    @State private var baseZoomScale: CGFloat = 1.0
    @State private var isZoomDialOpen: Bool = false
    @State private var flipRotation: Double = 0.0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // MARK: - 1. Viewfinder Layer (Hardware Native Preview)
            GeometryReader { geo in
                let viewSize = geo.size
                
                ZStack {
                    CameraPreviewView(session: cameraManager.session)
                        .frame(width: viewSize.width, height: viewSize.height)
                        .clipped()
                    
                    // AI Face Tracking Yellow Bounding Box Overlay
                    if let faces = faceTrackingEngine?.detectedFaces {
                        FaceBoundingBoxesView(faces: faces, viewSize: viewSize)
                    }
                    
                    // Manual Tap-to-Focus Reticle Box
                    if showFocusBox, let pt = manualFocusPoint {
                        FocusReticleView()
                            .position(pt)
                            .transition(.opacity)
                    }
                    
                    // Shutter White Flash Effect
                    if showFlashAnimation {
                        Color.white
                            .opacity(0.85)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
                // Tap-to-Focus Gesture on Viewfinder
                .onTapGesture { location in
                    handleTapToFocus(at: location, in: viewSize)
                }
                // Pinch to Zoom Gesture
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            let target = max(1.0, min(10.0, baseZoomScale * scale))
                            cameraManager.setZoom(target, animated: false)
                        }
                        .onEnded { _ in
                            baseZoomScale = cameraManager.currentZoomFactor
                        }
                )
            }
            .ignoresSafeArea()
            
            // MARK: - 2. HUD Controls (Z-Index 100 to guarantee touch priority)
            VStack(spacing: 0) {
                // Top Controls Bar (Safe below Notch / Dynamic Island)
                topControlsBar
                    .padding(.top, 8)
                
                Spacer()
                
                // Zoom Control Pill (1x / 2x & Ramping)
                zoomControlPill
                    .padding(.bottom, 12)
                
                // Camera Mode Swipe Carousel (PHOTO / VIDEO / PORTRAIT)
                modeSelectorCarousel
                    .padding(.bottom, 8)
                
                // Bottom Shutter & Action Bar
                bottomControlsBar
            }
            .zIndex(100)
        }
        .onAppear {
            setupEngine()
        }
    }
    
    // MARK: - Top Controls Bar
    private var topControlsBar: some View {
        HStack {
            // Flash Mode Toggle
            Button(action: {
                HapticManager.shared.tap()
                cycleFlashMode()
            }) {
                Image(systemName: flashIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(cameraManager.flashMode == .off ? .white : .yellow)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Live Photo Toggle
            Button(action: {
                HapticManager.shared.tap()
                cameraManager.isLivePhotoEnabled.toggle()
            }) {
                Image(systemName: cameraManager.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(cameraManager.isLivePhotoEnabled ? .yellow : .white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Zoom Control Pill (iPhone X/XS 1x Wide & 2x Telephoto)
    private var zoomControlPill: some View {
        HStack(spacing: 12) {
            // 1x Button (Wide Angle)
            Button(action: {
                HapticManager.shared.zoomTick()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    cameraManager.setZoom(1.0, animated: true)
                }
            }) {
                Text("1x")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(abs(cameraManager.currentZoomFactor - 1.0) < 0.2 ? .yellow : .white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(abs(cameraManager.currentZoomFactor - 1.0) < 0.2 ? 0.75 : 0.4))
                            .overlay(
                                Circle()
                                    .stroke(Color.yellow, lineWidth: abs(cameraManager.currentZoomFactor - 1.0) < 0.2 ? 1.5 : 0)
                            )
                    )
            }
            
            // 2x Button (Optical Telephoto)
            Button(action: {
                HapticManager.shared.zoomTick()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    cameraManager.setZoom(2.0, animated: true)
                }
            }) {
                Text("2x")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(abs(cameraManager.currentZoomFactor - 2.0) < 0.2 ? .yellow : .white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(abs(cameraManager.currentZoomFactor - 2.0) < 0.2 ? 0.75 : 0.4))
                            .overlay(
                                Circle()
                                    .stroke(Color.yellow, lineWidth: abs(cameraManager.currentZoomFactor - 2.0) < 0.2 ? 1.5 : 0)
                            )
                    )
            }
            
            // Continuous Zoom Indicator if zoomed beyond 2x
            if cameraManager.currentZoomFactor > 2.2 {
                Text(String(format: "%.1fx", cameraManager.currentZoomFactor))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.35)))
    }
    
    // MARK: - Mode Selector Carousel (PHOTO / VIDEO / PORTRAIT)
    private var modeSelectorCarousel: some View {
        HStack(spacing: 24) {
            ForEach(CameraMode.allCases) { mode in
                Button(action: {
                    HapticManager.shared.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        cameraManager.cameraMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: cameraManager.cameraMode == mode ? .bold : .semibold, design: .rounded))
                        .foregroundColor(cameraManager.cameraMode == mode ? .yellow : .white.opacity(0.6))
                        .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Bottom Controls Bar (Shutter, Gallery, Flip)
    private var bottomControlsBar: some View {
        HStack(alignment: .center) {
            // Left: Photo Gallery Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
                
                if let thumb = cameraManager.lastCapturedThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 70)
            
            Spacer()
            
            // Center: Apple Camera Native Shutter Button
            shutterButton
            
            Spacer()
            
            // Right: Flip Camera Button
            Button(action: {
                HapticManager.shared.shutter()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    flipRotation += 180
                }
                cameraManager.flipCamera()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(flipRotation))
                }
            }
            .frame(width: 70)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(height: 100)
    }
    
    // MARK: - Shutter Button View
    private var shutterButton: some View {
        Button(action: {
            HapticManager.shared.shutter()
            if cameraManager.isRecordingVideo {
                cameraManager.stopVideoRecording()
            } else if cameraManager.cameraMode == .video {
                cameraManager.startVideoRecording()
            } else {
                handlePhotoShutter()
            }
        }) {
            ZStack {
                // Outer White Ring (78pt, 4.5pt line width)
                Circle()
                    .stroke(Color.white, lineWidth: 4.5)
                    .frame(width: 78, height: 78)
                
                if cameraManager.isRecordingVideo {
                    // Recording Red Rounded Square
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    // Inner Solid White Circle
                    Circle()
                        .fill(cameraManager.cameraMode == .video ? Color.red : Color.white)
                        .frame(width: 64, height: 64)
                }
            }
        }
    }
    
    // MARK: - Helpers & Engine Setup
    private func setupEngine() {
        let engine = FaceTrackingEngine(cameraManager: cameraManager)
        self.faceTrackingEngine = engine
        
        cameraManager.onVideoSampleBuffer = { [weak engine] sampleBuffer in
            engine?.processSampleBuffer(sampleBuffer)
        }
        
        cameraManager.checkPermissionsAndConfigure { ok in
            if !ok {
                print("[CameraView] Camera permissions not granted.")
            }
        }
    }
    
    private func handlePhotoShutter() {
        withAnimation(.easeOut(duration: 0.08)) {
            showFlashAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeIn(duration: 0.10)) {
                showFlashAnimation = false
            }
        }
        cameraManager.capturePhoto()
    }
    
    private func handleTapToFocus(at point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        HapticManager.shared.tap()
        manualFocusPoint = point
        showFocusBox = true
        
        let normX = point.x / size.width
        let normY = point.y / size.height
        cameraManager.focus(at: CGPoint(x: normX, y: normY))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showFocusBox = false
            }
        }
    }
    
    private var flashIcon: String {
        switch cameraManager.flashMode {
        case .auto: return "bolt.badge.a.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        }
    }
    
    private func cycleFlashMode() {
        switch cameraManager.flashMode {
        case .auto: cameraManager.flashMode = .on
        case .on: cameraManager.flashMode = .off
        case .off: cameraManager.flashMode = .auto
        }
    }
}

// MARK: - Face Bounding Boxes View
public struct FaceBoundingBoxesView: View {
    public let faces: [TrackedFaceRect]
    public let viewSize: CGSize
    
    public var body: some View {
        ZStack {
            ForEach(faces) { face in
                let rect = CGRect(
                    x: face.boundingBox.origin.x * viewSize.width,
                    y: (1.0 - face.boundingBox.origin.y - face.boundingBox.height) * viewSize.height,
                    width: face.boundingBox.width * viewSize.width,
                    height: face.boundingBox.height * viewSize.height
                )
                
                ZStack(alignment: .topLeading) {
                    AppleFocusCornersShape()
                        .stroke(Color.yellow, lineWidth: 2.0)
                        .frame(width: rect.width, height: rect.height)
                }
                .position(x: rect.midX, y: rect.midY)
                .animation(.interpolatingSpring(stiffness: 350, damping: 28), value: rect)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Focus Reticle View
public struct FocusReticleView: View {
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

// MARK: - Corner Bracket Shape
public struct AppleFocusCornersShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = min(rect.width, rect.height) * 0.22
        
        // Top Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        
        // Top Right
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        
        // Bottom Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        
        // Bottom Left
        path.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        
        return path
    }
}
