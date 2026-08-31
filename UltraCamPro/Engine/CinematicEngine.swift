import Foundation
import Vision
import CoreVideo
import CoreMedia
import Combine

public final class CinematicEngine: ObservableObject {
    @Published public var isCinematicEnabled: Bool = false {
        didSet {
            if !isCinematicEnabled {
                self.onMaskGenerated?(nil)
            }
        }
    }
    @Published public var currentAperture: Double = 2.8 // f/1.4 to f/16
    @Published public var blurRadius: Float = 6.0
    
    private let segmentationRequest = VNGeneratePersonSegmentationRequest()
    private let sequenceHandler = VNSequenceRequestHandler()
    private let processingQueue = DispatchQueue(label: "com.ultracam.pro.cinematic-queue", qos: .userInteractive)
    private var isBusy = false
    
    public var onMaskGenerated: ((CVPixelBuffer?) -> Void)?
    
    public init() {
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }
    
    public func setAperture(_ aperture: Double) {
        self.currentAperture = aperture
        let t = max(0.0, min(1.0, (16.0 - aperture) / (16.0 - 1.4)))
        self.blurRadius = Float(t * 10.0)
    }
    
    public func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isCinematicEnabled else { return }
        guard !isBusy else { return }
        isBusy = true
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isBusy = false }
            
            guard self.isCinematicEnabled else {
                self.onMaskGenerated?(nil)
                return
            }
            
            do {
                try self.sequenceHandler.perform([self.segmentationRequest], on: pixelBuffer)
                if let maskResult = self.segmentationRequest.results?.first {
                    let maskBuffer = maskResult.pixelBuffer
                    self.onMaskGenerated?(maskBuffer)
                } else {
                    self.onMaskGenerated?(nil)
                }
            } catch {
                self.onMaskGenerated?(nil)
            }
        }
    }
}
