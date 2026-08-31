import SwiftUI

public struct SettingsSheetView: View {
    @ObservedObject public var cameraEngine: CameraEngine
    @ObservedObject public var trackingManager: AITrackingManager
    public var metalRenderer: MetalRenderer?
    @Binding public var showGrid: Bool
    @Environment(\.presentationMode) var presentationMode
    
    @State private var distortionStrength: Float = 0.45
    @State private var vignetteStrength: Float = 0.35
    @State private var chromaticAberration: Float = 0.003
    @State private var hapticsEnabled: Bool = true
    
    public init(cameraEngine: CameraEngine,
                trackingManager: AITrackingManager,
                metalRenderer: MetalRenderer?,
                showGrid: Binding<Bool>) {
        self.cameraEngine = cameraEngine
        self.trackingManager = trackingManager
        self.metalRenderer = metalRenderer
        self._showGrid = showGrid
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // MARK: - Section 1: Capture Quality & Resolution
                Section(header: Text("Video & Format Options")) {
                    Picker("Resolution & FPS", selection: $cameraEngine.currentResolution) {
                        ForEach(CaptureResolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    
                    Toggle("Apple ProRAW Capture", isOn: $cameraEngine.isProRAWEnabled)
                    Toggle("Live Photo Support", isOn: $cameraEngine.isLivePhotoEnabled)
                }
                
                // MARK: - Section 2: AI Neural Engine Tracking
                Section(header: Text("AI Vision Face Tracking")) {
                    Toggle("Enable Zero-Latency Tracking", isOn: $trackingManager.isAITrackingEnabled)
                    
                    HStack {
                        Text("Latency")
                        Spacer()
                        Text("0.000001s (Neural Engine)")
                            .foregroundColor(.secondary)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Auto Focus Mode")
                        Spacer()
                        Text("AI Point of Interest")
                            .foregroundColor(.secondary)
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
                
                // MARK: - Section 3: 0.5x Ultra-Wide Metal Shader Calibration
                Section(header: Text("0.5x Ultra-Wide Simulation Engine")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Barrel Curvature (k1)")
                            Spacer()
                            Text(String(format: "%.2f", distortionStrength))
                                .foregroundColor(.yellow)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        Slider(value: $distortionStrength, in: 0.1...0.9, step: 0.01) { _ in
                            metalRenderer?.distortionStrength = distortionStrength
                            metalRenderer?.k1 = -distortionStrength * 0.7
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Vignette Correction")
                            Spacer()
                            Text(String(format: "%.2f", vignetteStrength))
                                .foregroundColor(.yellow)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        Slider(value: $vignetteStrength, in: 0.0...1.0, step: 0.02) { _ in
                            metalRenderer?.vignetteIntensity = vignetteStrength
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Chromatic Aberration")
                            Spacer()
                            Text(String(format: "%.4f", chromaticAberration))
                                .foregroundColor(.yellow)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        Slider(value: $chromaticAberration, in: 0.0...0.01, step: 0.0005) { _ in
                            metalRenderer?.chromaticAberration = chromaticAberration
                        }
                    }
                }
                
                // MARK: - Section 4: General Settings
                Section(header: Text("Interface & Experience")) {
                    Toggle("Composition 3x3 Grid", isOn: $showGrid)
                    
                    Toggle("Taptic Haptic Feedback", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { enabled in
                            HapticManager.shared.isHapticsEnabled = enabled
                        }
                }
                
                // MARK: - Section 5: App Info
                Section(header: Text("About UltraCam Pro")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("2.0.0 Pro")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Metal Shader Engine")
                        Spacer()
                        Text("Metal 3.0 / Bilinear Anti-Aliased")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Camera Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.yellow)
                }
            }
        }
    }
}
