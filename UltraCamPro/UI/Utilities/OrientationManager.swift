import SwiftUI
import CoreMotion

public final class OrientationManager: ObservableObject {
    @Published public var deviceOrientation: UIDeviceOrientation = .portrait
    private let motionManager = CMMotionManager()
    
    public init() {
        startMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            
            let x = data.acceleration.x
            let y = data.acceleration.y
            
            if abs(y) >= abs(x) {
                if y <= -0.5 {
                    self.updateOrientation(.portrait)
                } else if y >= 0.5 {
                    self.updateOrientation(.portraitUpsideDown)
                }
            } else {
                if x <= -0.5 {
                    self.updateOrientation(.landscapeLeft)
                } else if x >= 0.5 {
                    self.updateOrientation(.landscapeRight)
                }
            }
        }
    }
    
    private func updateOrientation(_ newOrientation: UIDeviceOrientation) {
        if deviceOrientation != newOrientation {
            deviceOrientation = newOrientation
        }
    }
    
    public var rotationAngle: Angle {
        switch deviceOrientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }
}
