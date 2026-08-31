import Foundation
import CoreGraphics
import Combine

public final class AIFocusController: ObservableObject {
    
    @Published public var isLockedOnFace: Bool = false
    @Published public var currentFocusCoord: CGPoint? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private weak var cameraEngine: CameraEngine?
    private weak var trackingManager: AITrackingManager?
    
    private var lastFocusUpdate = Date.distantPast
    private let minUpdateInterval: TimeInterval = 0.05 // Limit rate to 20Hz to prevent focus hunting jitter
    
    public init(cameraEngine: CameraEngine, trackingManager: AITrackingManager) {
        self.cameraEngine = cameraEngine
        self.trackingManager = trackingManager
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        trackingManager?.$primaryFocusPoint
            .receive(on: DispatchQueue.main)
            .sink { [weak self] point in
                guard let self = self else { return }
                if let point = point {
                    self.isLockedOnFace = true
                    self.currentFocusCoord = point
                    
                    let now = Date()
                    if now.timeIntervalSince(self.lastFocusUpdate) >= self.minUpdateInterval {
                        self.lastFocusUpdate = now
                        self.cameraEngine?.applyAIFocus(at: point)
                    }
                } else {
                    self.isLockedOnFace = false
                    self.currentFocusCoord = nil
                }
            }
            .store(in: &cancellables)
    }
}
