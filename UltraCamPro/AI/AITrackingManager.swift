import Foundation
import Vision
import CoreVideo
import CoreMedia
import Combine
import UIKit

public struct TrackedFace: Identifiable, Equatable {
    public let id: UUID
    public var boundingBox: CGRect // Normalized [0.0 ... 1.0] Vision coordinates
    public var confidence: Float
    public var roll: Double?
    public var yaw: Double?
    public var lastSeen: Date
    public var isPrimary: Bool
}

public final class AITrackingManager: ObservableObject {
    
    // MARK: - Published Outputs for SwiftUI UI
    @Published public var detectedFaces: [TrackedFace] = []
    @Published public var primaryFocusPoint: CGPoint?
    @Published public var isAITrackingEnabled: Bool = true
    
    // MARK: - Internal Vision Engine
    private let sequenceHandler = VNSequenceRequestHandler()
    private let processingQueue = DispatchQueue(label: "com.ultracam.pro.ai-tracking-queue", qos: .userInteractive)
    private var isBusyProcessing = false
    
    // Smoothing coefficient for Exponential Moving Average (0.0 to 1.0)
    private let smoothingAlpha: CGFloat = 0.65
    private var smoothedBoxes: [UUID: CGRect] = [:]
    
    public init() {}
    
    // MARK: - High Performance Neural Engine Face Detection Pipeline
    public func processFrame(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) {
        guard isAITrackingEnabled else {
            if !detectedFaces.isEmpty {
                DispatchQueue.main.async {
                    self.detectedFaces = []
                    self.primaryFocusPoint = nil
                }
            }
            return
        }
        
        // Skip frame if previous Neural Engine pass is still executing to maintain 0 latency
        guard !isBusyProcessing else { return }
        isBusyProcessing = true
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isBusyProcessing = false }
            
            let request = VNDetectFaceRectanglesRequest { [weak self] req, error in
                guard let self = self,
                      error == nil,
                      let observations = req.results as? [VNFaceObservation] else {
                    DispatchQueue.main.async {
                        self?.detectedFaces = []
                        self?.primaryFocusPoint = nil
                    }
                    return
                }
                
                self.handleFaceObservations(observations)
            }
            
            // Set Vision request configuration for maximum speed and profile/angle detection
            request.revision = VNDetectFaceRectanglesRequestRevision3
            request.preferBackgroundProcessing = false
            
            do {
                try self.sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
            } catch {
                print("[AITrackingManager] Vision perform error: \(error)")
            }
        }
    }
    
    // MARK: - Temporal Filtering & Box Stabilization
    private func handleFaceObservations(_ observations: [VNFaceObservation]) {
        var updatedFaces: [TrackedFace] = []
        let now = Date()
        
        // Sort faces by size (largest face is primary focus)
        let sortedObservations = observations.sorted { ($0.boundingBox.width * $0.boundingBox.height) > ($1.boundingBox.width * $1.boundingBox.height) }
        
        for (index, obs) in sortedObservations.enumerated() {
            let rawBox = obs.boundingBox
            let faceId = UUID()
            
            // Apply Exponential Moving Average (EMA) smoothing for silky 60fps tracking
            let smoothedBox = smoothBoundingBox(newBox: rawBox, for: faceId)
            
            let tracked = TrackedFace(
                id: faceId,
                boundingBox: smoothedBox,
                confidence: obs.confidence,
                roll: obs.roll?.doubleValue,
                yaw: obs.yaw?.doubleValue,
                lastSeen: now,
                isPrimary: (index == 0)
            )
            updatedFaces.append(tracked)
        }
        
        // Calculate primary focus point for AVFoundation FocusPointOfInterest
        var computedFocusPoint: CGPoint? = nil
        if let primary = updatedFaces.first {
            // Convert Vision coordinate (bottom-left origin) to AVCaptureDevice normalized space (top-left origin)
            let centerX = primary.boundingBox.midX
            let centerY = primary.boundingBox.midY
            computedFocusPoint = CGPoint(x: centerX, y: 1.0 - centerY)
        }
        
        DispatchQueue.main.async {
            self.detectedFaces = updatedFaces
            self.primaryFocusPoint = computedFocusPoint
        }
    }
    
    private func smoothBoundingBox(newBox: CGRect, for id: UUID) -> CGRect {
        guard let prevBox = smoothedBoxes[id] else {
            smoothedBoxes[id] = newBox
            return newBox
        }
        
        let smoothX = prevBox.origin.x * (1.0 - smoothingAlpha) + newBox.origin.x * smoothingAlpha
        let smoothY = prevBox.origin.y * (1.0 - smoothingAlpha) + newBox.origin.y * smoothingAlpha
        let smoothW = prevBox.size.width * (1.0 - smoothingAlpha) + newBox.size.width * smoothingAlpha
        let smoothH = prevBox.size.height * (1.0 - smoothingAlpha) + newBox.size.height * smoothingAlpha
        
        let result = CGRect(x: smoothX, y: smoothY, width: smoothW, height: smoothH)
        smoothedBoxes[id] = result
        return result
    }
}
