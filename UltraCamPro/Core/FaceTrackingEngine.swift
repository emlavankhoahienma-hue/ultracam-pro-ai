import Foundation
import Vision
import CoreMedia
import CoreVideo
import Combine

public struct TrackedFaceRect: Identifiable, Equatable {
    public let id: UUID
    public var boundingBox: CGRect // Normalized [0, 1] coordinates
    public var confidence: Float
}

public final class FaceTrackingEngine: ObservableObject {
    @Published public var detectedFaces: [TrackedFaceRect] = []
    
    private let sequenceHandler = VNSequenceRequestHandler()
    private let processingQueue = DispatchQueue(label: "com.ultracam.pro.facetracking", qos: .userInteractive)
    private var isBusy: Bool = false
    private weak var cameraManager: CameraManager?
    
    private var lastFocusTime = Date.distantPast
    
    public init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
    }
    
    public func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard !isBusy, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        isBusy = true
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isBusy = false }
            
            let request = VNDetectFaceRectanglesRequest { [weak self] req, error in
                guard let self = self, error == nil,
                      let observations = req.results as? [VNFaceObservation] else {
                    DispatchQueue.main.async {
                        self?.detectedFaces = []
                    }
                    return
                }
                
                let faces = observations.map { obs in
                    TrackedFaceRect(
                        id: UUID(),
                        boundingBox: obs.boundingBox,
                        confidence: obs.confidence
                    )
                }
                
                DispatchQueue.main.async {
                    self.detectedFaces = faces
                }
                
                // Auto Focus directly onto primary face center
                if let primary = observations.first {
                    let now = Date()
                    if now.timeIntervalSince(self.lastFocusTime) >= 0.1 {
                        self.lastFocusTime = now
                        let centerX = primary.boundingBox.midX
                        let centerY = 1.0 - primary.boundingBox.midY
                        self.cameraManager?.focus(at: CGPoint(x: centerX, y: centerY))
                    }
                }
            }
            
            request.revision = VNDetectFaceRectanglesRequestRevision3
            request.preferBackgroundProcessing = false
            
            do {
                try self.sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
            } catch {
                // Ignore frame drop
            }
        }
    }
}
