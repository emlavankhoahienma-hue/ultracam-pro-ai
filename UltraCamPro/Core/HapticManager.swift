import UIKit

public final class HapticManager {
    public static let shared = HapticManager()
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    private init() {
        impactFeedback.prepare()
        lightImpact.prepare()
        selectionFeedback.prepare()
    }
    
    public func shutter() {
        impactFeedback.impactOccurred()
    }
    
    public func tap() {
        lightImpact.impactOccurred()
    }
    
    public func zoomTick() {
        selectionFeedback.selectionChanged()
    }
}
