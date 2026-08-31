import Foundation
import AVFoundation
import UIKit
import Photos
import Combine

public enum CameraMode: String, CaseIterable, Identifiable {
    case photo = "PHOTO"
    case video = "VIDEO"
    case portrait = "PORTRAIT"
    
    public var id: String { rawValue }
}

public enum FlashMode {
    case auto
    case on
    case off
    
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
}

public final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties for SwiftUI
    @Published public var isSessionRunning: Bool = false
    @Published public var currentZoomFactor: CGFloat = 1.0
    @Published public var isRecordingVideo: Bool = false
    @Published public var cameraMode: CameraMode = .photo
    @Published public var flashMode: FlashMode = .auto
    @Published public var isLivePhotoEnabled: Bool = true
    @Published public var isFrontCamera: Bool = false
    @Published public var lastCapturedThumbnail: UIImage?
    @Published public var opticalZoomSwitchFactor: CGFloat = 2.0 // Dual camera telephoto factor
    
    // MARK: - Callbacks
    public var onVideoSampleBuffer: ((CMSampleBuffer) -> Void)?
    public var onPhotoCaptured: ((UIImage) -> Void)?
    
    // MARK: - AVFoundation Internals
    public let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ultracam.pro.sessionQueue", qos: .userInteractive)
    private let videoDataQueue = DispatchQueue(label: "com.ultracam.pro.videoDataQueue", qos: .userInteractive)
    
    public var currentDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    
    private let photoOutput = AVCapturePhotoOutput()
    private let movieFileOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    // MARK: - Initialization
    public override init() {
        super.init()
    }
    
    // MARK: - Permission & Setup
    public func checkPermissionsAndConfigure(completion: @escaping (Bool) -> Void) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        let group = DispatchGroup()
        var granted = (cameraStatus == .authorized)
        
        if cameraStatus == .notDetermined {
            group.enter()
            AVCaptureDevice.requestAccess(for: .video) { ok in
                granted = ok
                group.leave()
            }
        }
        
        if audioStatus == .notDetermined {
            group.enter()
            AVCaptureDevice.requestAccess(for: .audio) { _ in
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
            if granted {
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
    
    // MARK: - Session Configuration (Background Thread)
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // 1. Select Dual Camera on iPhone X/XS (Automatic 1x Wide & 2x Telephoto)
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: isFrontCamera ? .front : .back
        )
        
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            print("[CameraManager] No video device found.")
            session.commitConfiguration()
            return
        }
        
        self.currentDevice = device
        
        // 2. Video Input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoDeviceInput = input
            }
        } catch {
            print("[CameraManager] Error adding video input: \(error)")
        }
        
        // 3. Audio Input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    self.audioDeviceInput = audioInput
                }
            } catch {
                print("[CameraManager] Error adding audio input: \(error)")
            }
        }
        
        // 4. Photo Output
        photoOutput.maxPhotoQualityPrioritization = .quality
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            }
        }
        
        // 5. Movie Output (4K 60fps capable)
        if session.canAddOutput(movieFileOutput) {
            session.addOutput(movieFileOutput)
        }
        
        // 6. Video Data Output (For Zero-Latency AI Tracking)
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        
        // 7. Lock Video Orientations to Portrait
        updateConnectionOrientations()
        
        // 8. Configure Hardware 4K60 / High Framerate
        configureDeviceFormats(for: device)
        
        session.commitConfiguration()
    }
    
    private func configureDeviceFormats(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // Enable continuous autofocus and autoexposure by default
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            // Configure 60fps format if supported
            for format in device.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate >= 60.0 && range.minFrameRate <= 60.0 {
                        device.activeFormat = format
                        let duration = CMTime(value: 1, timescale: 60)
                        device.activeVideoMinFrameDuration = duration
                        device.activeVideoMaxFrameDuration = duration
                        break
                    }
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("[CameraManager] Could not lock device configuration: \(error)")
        }
    }
    
    private func updateConnectionOrientations() {
        let isFront = self.isFrontCamera
        
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFront
            }
        }
        
        if let movieConn = movieFileOutput.connection(with: .video) {
            if movieConn.isVideoOrientationSupported {
                movieConn.videoOrientation = .portrait
            }
            if movieConn.isVideoMirroringSupported {
                movieConn.isVideoMirrored = isFront
            }
        }
        
        if let videoConn = videoDataOutput.connection(with: .video) {
            if videoConn.isVideoOrientationSupported {
                videoConn.videoOrientation = .portrait
            }
            if videoConn.isVideoMirroringSupported {
                videoConn.isVideoMirrored = isFront
            }
        }
    }
    
    // MARK: - Lifecycle Controls (Background Queue)
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
    
    // MARK: - Buttery-Smooth Zoom Control (1x - 10x with Optical 2x Telephoto Ramping)
    public func setZoom(_ factor: CGFloat, animated: Bool = true) {
        let clamped = max(1.0, min(10.0, factor))
        
        DispatchQueue.main.async {
            self.currentZoomFactor = clamped
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                let targetZoom = min(clamped, device.activeFormat.videoMaxZoomFactor)
                if animated {
                    device.ramp(toVideoZoomFactor: targetZoom, withRate: 15.0)
                } else {
                    device.videoZoomFactor = targetZoom
                }
                device.unlockForConfiguration()
            } catch {
                print("[CameraManager] Zoom ramp error: \(error)")
            }
        }
    }
    
    // MARK: - Fast Camera Switching (Hot Swap with Zero Freezing)
    public func flipCamera() {
        let targetFront = !isFrontCamera
        isFrontCamera = targetFront
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInDualCamera,
                    .builtInDualWideCamera,
                    .builtInWideAngleCamera
                ],
                mediaType: .video,
                position: targetFront ? .front : .back
            )
            
            guard let newDevice = discovery.devices.first else {
                self.session.commitConfiguration()
                return
            }
            
            self.currentDevice = newDevice
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                }
            } catch {
                print("[CameraManager] Error hot-swapping camera: \(error)")
            }
            
            self.updateConnectionOrientations()
            self.configureDeviceFormats(for: newDevice)
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.currentZoomFactor = 1.0
            }
        }
    }
    
    // MARK: - Hardware Auto-Focus & Auto-Exposure
    public func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                // Ignore focus lock error
            }
        }
    }
    
    // MARK: - Photo Capture
    public func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            var settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            if self.currentDevice?.isFlashAvailable == true {
                settings.flashMode = self.flashMode.avFlashMode
            }
            settings.photoQualityPrioritization = .quality
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Video Recording
    public func startVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.movieFileOutput.isRecording else { return }
            
            let tempDir = NSTemporaryDirectory()
            let filePath = (tempDir as NSString).appendingPathComponent(UUID().uuidString + ".mov")
            let fileURL = URL(fileURLWithPath: filePath)
            
            self.movieFileOutput.startRecording(to: fileURL, recordingDelegate: self)
            DispatchQueue.main.async { self.isRecordingVideo = true }
        }
    }
    
    public func stopVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.movieFileOutput.isRecording else { return }
            self.movieFileOutput.stopRecording()
            DispatchQueue.main.async { self.isRecordingVideo = false }
        }
    }
    
    // MARK: - Save to Library Helper
    private func saveImageToLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if let error = error {
                print("[CameraManager] Save error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.onVideoSampleBuffer?(sampleBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        
        self.saveImageToLibrary(image)
        DispatchQueue.main.async {
            self.lastCapturedThumbnail = image
            self.onPhotoCaptured?(image)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else {
            print("[CameraManager] Video recording error: \(String(describing: error))")
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { _, _ in
            try? FileManager.default.removeItem(at: outputFileURL)
        }
    }
}
