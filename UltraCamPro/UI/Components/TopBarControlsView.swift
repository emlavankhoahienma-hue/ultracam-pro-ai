import SwiftUI

public struct TopBarControlsView: View {
    @ObservedObject public var cameraEngine: CameraEngine
    @ObservedObject public var trackingManager: AITrackingManager
    @ObservedObject public var cinematicEngine: CinematicEngine
    @ObservedObject public var lutEngine: LUTEngine
    public let onOpenSettings: () -> Void
    
    public init(cameraEngine: CameraEngine,
                trackingManager: AITrackingManager,
                cinematicEngine: CinematicEngine,
                lutEngine: LUTEngine,
                onOpenSettings: @escaping () -> Void) {
        self.cameraEngine = cameraEngine
        self.trackingManager = trackingManager
        self.cinematicEngine = cinematicEngine
        self.lutEngine = lutEngine
        self.onOpenSettings = onOpenSettings
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Flash Mode Toggle
            Button(action: {
                HapticManager.shared.triggerLightTap()
                cycleFlashMode()
            }) {
                Image(systemName: flashIconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(cameraEngine.flashMode == .off ? .white : .yellow)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Live Photo Toggle
            Button(action: {
                HapticManager.shared.triggerLightTap()
                cameraEngine.isLivePhotoEnabled.toggle()
            }) {
                Image(systemName: cameraEngine.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(cameraEngine.isLivePhotoEnabled ? .yellow : .white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Cinematic Video Mode Toggle
            Button(action: {
                HapticManager.shared.triggerRigidSnap()
                withAnimation {
                    cinematicEngine.isCinematicEnabled.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(cinematicEngine.isCinematicEnabled ? Color.yellow : Color.clear)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    
                    Text("ƒ")
                        .font(.system(size: 18, weight: .black, design: .serif))
                        .foregroundColor(cinematicEngine.isCinematicEnabled ? .black : .white)
                }
            }
            
            Spacer()
            
            // 3D Film LUT Preset Selector Toggle
            Button(action: {
                HapticManager.shared.triggerLightTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    lutEngine.isLUTPanelOpen.toggle()
                }
            }) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(lutEngine.activePreset != .natural ? .yellow : .white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // ProRAW Toggle Badge
            Button(action: {
                HapticManager.shared.triggerRigidSnap()
                cameraEngine.isProRAWEnabled.toggle()
            }) {
                Text("RAW")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(cameraEngine.isProRAWEnabled ? .black : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(cameraEngine.isProRAWEnabled ? Color.yellow : Color.white.opacity(0.18))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // AI Face Tracking Toggle
            Button(action: {
                HapticManager.shared.triggerLightTap()
                trackingManager.isAITrackingEnabled.toggle()
            }) {
                Image(systemName: trackingManager.isAITrackingEnabled ? "face.dashed.fill" : "face.dashed")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(trackingManager.isAITrackingEnabled ? .yellow : .gray)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Settings Gear Icon
            Button(action: {
                HapticManager.shared.triggerRigidSnap()
                onOpenSettings()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var flashIconName: String {
        switch cameraEngine.flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        }
    }
    
    private func cycleFlashMode() {
        switch cameraEngine.flashMode {
        case .auto:
            cameraEngine.flashMode = .on
        case .on:
            cameraEngine.flashMode = .off
        case .off:
            cameraEngine.flashMode = .auto
        }
    }
}
