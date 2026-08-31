import SwiftUI

public struct BottomBarControlsView: View {
    @ObservedObject public var cameraEngine: CameraEngine
    public let onShutterTap: () -> Void
    public let onFlipCamera: () -> Void
    public let onOpenGallery: () -> Void
    
    @State private var isShutterPressed: Bool = false
    @State private var flipRotation: Double = 0.0
    
    public init(cameraEngine: CameraEngine,
                onShutterTap: @escaping () -> Void,
                onFlipCamera: @escaping () -> Void,
                onOpenGallery: @escaping () -> Void) {
        self.cameraEngine = cameraEngine
        self.onShutterTap = onShutterTap
        self.onFlipCamera = onFlipCamera
        self.onOpenGallery = onOpenGallery
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            // MARK: - Left: Photo Thumbnail
            Button(action: {
                HapticManager.shared.triggerLightTap()
                onOpenGallery()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 54, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        )
                    
                    if let thumb = cameraEngine.lastCapturedThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 72)
            
            Spacer()
            
            // MARK: - Center: Native Apple Style Shutter Button
            shutterButtonView
            
            Spacer()
            
            // MARK: - Right: Flip Camera
            Button(action: {
                HapticManager.shared.triggerRigidSnap()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    flipRotation += 180
                }
                onFlipCamera()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(flipRotation))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 72)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(height: 100)
    }
    
    // MARK: - Shutter Button View
    private var shutterButtonView: some View {
        Button(action: {
            HapticManager.shared.triggerShutterPress()
            if cameraEngine.isRecordingVideo {
                cameraEngine.stopVideoRecording()
            } else {
                onShutterTap()
            }
        }) {
            ZStack {
                // Outer White Ring
                Circle()
                    .stroke(Color.white, lineWidth: 4.5)
                    .frame(width: 78, height: 78)
                
                if cameraEngine.isRecordingVideo {
                    // Recording State: Red Rounded Square
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    // Photo State: Inner Solid White Circle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                        .scaleEffect(isShutterPressed ? 0.88 : 1.0)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    HapticManager.shared.triggerRigidSnap()
                    cameraEngine.startVideoRecording()
                }
        )
    }
}
