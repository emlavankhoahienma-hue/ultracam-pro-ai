import UIKit

public final class HapticManager {
    public static let shared = HapticManager()
    
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    public var isHapticsEnabled: Bool = true
    
    private init() {
        selectionFeedback.prepare()
        lightImpact.prepare()
        rigidImpact.prepare()
    }
    
    public func triggerSelectionTick() {
        guard isHapticsEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    public func triggerLightTap() {
        guard isHapticsEnabled else { return }
        lightImpact.impactOccurred()
    }
    
    public func triggerRigidSnap() {
        guard isHapticsEnabled else { return }
        rigidImpact.impactOccurred()
    }
    
    public func triggerShutterPress() {
        guard isHapticsEnabled else { return }
        heavyImpact.impactOccurred()
    }
    
    public func triggerSuccess() {
        guard isHapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }
    
    public func triggerWarning() {
        guard isHapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }
}
