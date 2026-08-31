import SwiftUI

public struct TopBarControlsView: View {
    @ObservedObject public var cameraEngine: CameraEngine
    @ObservedObject public var trackingManager: AITrackingManager
    public let onOpenSettings: () -> Void
    
    public init(cameraEngine: CameraEngine, trackingManager: AITrackingManager, onOpenSettings: @escaping () -> Void) {
        self.cameraEngine = cameraEngine
        self.trackingManager = trackingManager
        self.onOpenSettings = onOpenSettings
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Flash Mode Toggle
            Button(action: {
                HapticManager.shared.triggerLightTap()
                cycleFlashMode()
            }) {
                Image(systemName: flashIconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(cameraEngine.flashMode == .off ? .white : .yellow)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Live Photo Toggle
            Button(action: {
                HapticManager.shared.triggerLightTap()
                cameraEngine.isLivePhotoEnabled.toggle()
            }) {
                Image(systemName: cameraEngine.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(cameraEngine.isLivePhotoEnabled ? .yellow : .white)
                    .frame(width: 44, height: 44)
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cameraEngine.isProRAWEnabled ? Color.yellow : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.8), lineWidth: cameraEngine.isProRAWEnabled ? 0 : 1.2)
                            )
                    )
            }
            
            Spacer()
            
            // AI Face Tracking Indicator / Switch
            Button(action: {
                HapticManager.shared.triggerLightTap()
                trackingManager.isAITrackingEnabled.toggle()
            }) {
                Image(systemName: trackingManager.isAITrackingEnabled ? "face.dashed.fill" : "face.dashed")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(trackingManager.isAITrackingEnabled ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Settings Gear Icon
            Button(action: {
                HapticManager.shared.triggerRigidSnap()
                onOpenSettings()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.black.opacity(0.45))
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
