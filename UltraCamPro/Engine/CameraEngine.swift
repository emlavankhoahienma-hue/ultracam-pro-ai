import Foundation
import AVFoundation
import UIKit
import Photos
import Combine

public enum CameraPosition {
    case back
    case front
}

public enum FlashMode {
    case off
    case on
    case auto
    
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }
}

public enum CaptureResolution: String, CaseIterable, Identifiable {
    case res4K60 = "4K 60fps"
    case res4K30 = "4K 30fps"
    case res1080p60 = "1080p 60fps"
    case res1080p30 = "1080p 30fps"
    
    public var id: String { rawValue }
    
    var sessionPreset: AVCaptureSession.Preset {
        switch self {
        case .res4K60, .res4K30:
            return .hd4K3840x2160
        case .res1080p60, .res1080p30:
            return .hd1920x1080
        }
    }
    
    var targetFPS: Double {
        switch self {
        case .res4K60, .res1080p60:
            return 60.0
        case .res4K30, .res1080p30:
            return 30.0
        }
    }
}

public final class CameraEngine: NSObject, ObservableObject {
    
    // MARK: - Published States
    @Published public var isSessionRunning: Bool = false
    @Published public var currentZoomFactor: CGFloat = 1.0
    @Published public var isRecordingVideo: Bool = false
    @Published public var flashMode: FlashMode = .auto
    @Published public var isLivePhotoEnabled: Bool = false
    @Published public var isProRAWEnabled: Bool = false
    @Published public var currentResolution: CaptureResolution = .res4K60
    @Published public var cameraPosition: CameraPosition = .back
    @Published public var lastCapturedThumbnail: UIImage?
    
    // MARK: - Callbacks for AI & Rendering
    public var onFrameReceived: ((CVPixelBuffer) -> Void)?
    public var onPhotoCaptured: ((UIImage) -> Void)?
    
    // MARK: - AVFoundation Internals
    public let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ultracam.pro.session-queue", qos: .userInteractive)
    private let videoOutputQueue = DispatchQueue(label: "com.ultracam.pro.video-queue", qos: .userInteractive)
    
    public var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var movieFileOutput: AVCaptureMovieFileOutput?
    
    public var metalRenderer: MetalRenderer?
    
    // MARK: - Initialization
    public override init() {
        super.init()
    }
    
    // MARK: - Permissions & Setup
    public func requestPermissionsAndConfigure(completion: @escaping (Bool) -> Void) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        let group = DispatchGroup()
        var grantedCamera = (cameraStatus == .authorized)
        var grantedAudio = (audioStatus == .authorized)
        
        if cameraStatus == .notDetermined {
            group.enter()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                grantedCamera = granted
                group.leave()
            }
        }
        
        if audioStatus == .notDetermined {
            group.enter()
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                grantedAudio = granted
                group.leave()
            }
        }
        
        if photoStatus == .notDetermined {
            group.enter()
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if grantedCamera {
                self.sessionQueue.async {
                    self.configureSession()
                    self.startSession()
                    DispatchQueue.main.async { completion(true) }
                }
            } else {
                completion(false)
            }
        }
    }
    
    // MARK: - Session Configuration
    private func configureSession() {
        session.beginConfiguration()
        
        // Select optimal preset
        if session.canSetSessionPreset(currentResolution.sessionPreset) {
            session.sessionPreset = currentResolution.sessionPreset
        } else {
            session.sessionPreset = .photo
        }
        
        // Setup Video Device
        let preferredPosition: AVCaptureDevice.Position = (cameraPosition == .back) ? .back : .front
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: preferredPosition
        )
        
        guard let device = discoverySession.devices.first ?? AVCaptureDevice.default(for: .video) else {
            print("[CameraEngine] No video capture device found.")
            session.commitConfiguration()
            return
        }
        
        self.videoDevice = device
        
        // Video Input
        do {
            let videoInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.videoInput = videoInput
            }
        } catch {
            print("[CameraEngine] Could not create video input: \(error)")
        }
        
        // Audio Input for Video Recording
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    self.audioInput = audioInput
                }
            } catch {
                print("[CameraEngine] Could not create audio input: \(error)")
            }
        }
        
        // Video Data Output for Metal Shader & AI Processing
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        
        // Photo Output with ProRAW & High Quality
        photoOutput.maxPhotoQualityPrioritization = .quality
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            }
        }
        
        // Movie File Output for 4K Video Recording
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.movieFileOutput = movieOutput
        }
        
        // Configure Frame Rate (e.g. 60fps)
        configureFrameRate(for: device, targetFPS: currentResolution.targetFPS)
        
        session.commitConfiguration()
    }
    
    private func configureFrameRate(for device: AVCaptureDevice, targetFPS: Double) {
        do {
            try device.lockForConfiguration()
            var bestFormat: AVCaptureDevice.Format?
            var bestFrameRateRange: AVFrameRateRange?
            
            for format in device.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate >= targetFPS && range.minFrameRate <= targetFPS {
                        if bestFormat == nil || format.formatDescription.dimensions.width > bestFormat!.formatDescription.dimensions.width {
                            bestFormat = format
                            bestFrameRateRange = range
                        }
                    }
                }
            }
            
            if let format = bestFormat, let range = bestFrameRateRange {
                device.activeFormat = format
                let targetDuration = CMTime(value: 1, timescale: CMTimeScale(range.maxFrameRate >= targetFPS ? targetFPS : range.maxFrameRate))
                device.activeVideoMinFrameDuration = targetDuration
                device.activeVideoMaxFrameDuration = targetDuration
            }
            
            // Enable Low Light Boost if available
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            device.unlockForConfiguration()
        } catch {
            print("[CameraEngine] Could not lock device for frame rate configuration: \(error)")
        }
    }
    
    // MARK: - Lifecycle Controls
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = self.session.isRunning }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }
    
    // MARK: - Zoom Control (Optical Ramp & Software 0.5x Ultra-Wide Shader)
    public func setZoomFactor(_ factor: CGFloat, animated: Bool = true) {
        let clampedFactor = max(0.5, min(5.0, factor))
        DispatchQueue.main.async {
            self.currentZoomFactor = clampedFactor
            self.metalRenderer?.zoomFactor = Float(clampedFactor)
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice else { return }
            
            do {
                try device.lockForConfiguration()
                if clampedFactor >= 1.0 {
                    let hardwareZoom = min(clampedFactor, device.activeFormat.videoMaxZoomFactor)
                    if animated {
                        device.ramp(toVideoZoomFactor: hardwareZoom, withRate: 8.0)
                    } else {
                        device.videoZoomFactor = hardwareZoom
                    }
                } else {
                    // Zoom factor < 1.0: Hardware stays at 1.0x, Metal shader applies Barrel Distortion & FOV expansion
                    if device.videoZoomFactor != 1.0 {
                        if animated {
                            device.ramp(toVideoZoomFactor: 1.0, withRate: 8.0)
                        } else {
                            device.videoZoomFactor = 1.0
                        }
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("[CameraEngine] Failed to apply zoom: \(error)")
            }
        }
    }
    
    // MARK: - Switch Camera
    public func toggleCameraPosition() {
        cameraPosition = (cameraPosition == .back) ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.stopRunning()
            
            // Remove existing inputs
            if let currentInput = self.videoInput {
                self.session.removeInput(currentInput)
            }
            if let currentAudio = self.audioInput {
                self.session.removeInput(currentAudio)
            }
            
            // Remove outputs
            self.session.removeOutput(self.videoDataOutput)
            self.session.removeOutput(self.photoOutput)
            if let movieOut = self.movieFileOutput {
                self.session.removeOutput(movieOut)
            }
            
            self.configureSession()
            self.startSession()
        }
    }
    
    // MARK: - Photo Capture (RAW / 0.5x Metal Rendered / Native)
    public func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If currently at 0.5x simulated ultra-wide zoom, capture rendered Metal frame
            if self.currentZoomFactor < 1.0, let renderer = self.metalRenderer, let lastBuffer = self.latestPixelBuffer {
                if let processedImage = renderer.renderProcessedImage(from: lastBuffer) {
                    self.saveImageToPhotoLibrary(processedImage)
                    DispatchQueue.main.async {
                        self.lastCapturedThumbnail = processedImage
                        self.onPhotoCaptured?(processedImage)
                    }
                    return
                }
            }
            
            // Standard / ProRAW Capture via AVCapturePhotoOutput
            var photoSettings: AVCapturePhotoSettings
            if self.isProRAWEnabled && self.photoOutput.availableRawPhotoPixelFormatTypes.contains(kCVPixelFormatType_14Bayer_RGGB) {
                photoSettings = AVCapturePhotoSettings(rawPixelFormatType: kCVPixelFormatType_14Bayer_RGGB, processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.videoDevice?.isFlashAvailable == true {
                photoSettings.flashMode = self.flashMode.avFlashMode
            }
            photoSettings.photoQualityPrioritization = .quality
            
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - Video Recording
    public func startVideoRecording() {
        guard let movieOutput = movieFileOutput, !movieOutput.isRecording else { return }
        
        let outputFileName = UUID().uuidString
        let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
        let outputFileURL = URL(fileURLWithPath: outputFilePath)
        
        movieOutput.startRecording(to: outputFileURL, recordingDelegate: self)
        DispatchQueue.main.async { self.isRecordingVideo = true }
    }
    
    public func stopVideoRecording() {
        guard let movieOutput = movieFileOutput, movieOutput.isRecording else { return }
        movieOutput.stopRecording()
        DispatchQueue.main.async { self.isRecordingVideo = false }
    }
    
    // MARK: - AI Smart Focus Point Command
    public func applyAIFocus(at pointOfInterest: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = pointOfInterest
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = pointOfInterest
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                // Focus lock skipped
            }
        }
    }
    
    // Cache for latest buffer
    private var latestPixelBuffer: CVPixelBuffer?
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if let error = error {
                print("[CameraEngine] Error saving photo: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        self.latestPixelBuffer = pixelBuffer
        self.metalRenderer?.updatePixelBuffer(pixelBuffer)
        self.onFrameReceived?(pixelBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraEngine: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            print("[CameraEngine] Capture error: \(String(describing: error))")
            return
        }
        
        self.saveImageToPhotoLibrary(image)
        DispatchQueue.main.async {
            self.lastCapturedThumbnail = image
            self.onPhotoCaptured?(image)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraEngine: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else {
            print("[CameraEngine] Video recording error: \(String(describing: error))")
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { success, error in
            try? FileManager.default.removeItem(at: outputFileURL)
        }
    }
}
