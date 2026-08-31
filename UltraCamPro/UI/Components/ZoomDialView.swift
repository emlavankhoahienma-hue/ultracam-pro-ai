import SwiftUI

public struct ZoomDialView: View {
    @Binding public var zoomFactor: CGFloat
    public let onZoomChanged: (CGFloat) -> Void
    
    @State private var isDialActive: Bool = false
    @State private var dragOffset: CGFloat = 0.0
    @State private var lastReportedZoomStep: Int = 10
    
    private let zoomPresets: [CGFloat] = [0.5, 1.0, 2.0, 3.0, 5.0]
    
    public init(zoomFactor: Binding<CGFloat>, onZoomChanged: @escaping (CGFloat) -> Void) {
        self._zoomFactor = zoomFactor
        self.onZoomChanged = onZoomChanged
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            if isDialActive {
                // Expanded Fine-grained Zoom Wheel
                expandedDialWheel
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Standard Preset Buttons
                presetButtonsRow
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDialActive)
    }
    
    // MARK: - Preset Buttons Row
    private var presetButtonsRow: some View {
        HStack(spacing: 16) {
            ForEach(zoomPresets, id: \.self) { preset in
                Button(action: {
                    HapticManager.shared.triggerRigidSnap()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        zoomFactor = preset
                    }
                    onZoomChanged(preset)
                }) {
                    ZStack {
                        if isSelected(preset: preset) {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.yellow, lineWidth: 1.5)
                                )
                        } else {
                            Circle()
                                .fill(Color.black.opacity(0.35))
                                .frame(width: 36, height: 36)
                        }
                        
                        Text(formatPresetText(preset))
                            .font(.system(size: isSelected(preset: preset) ? 14 : 12, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected(preset: preset) ? .yellow : .white.opacity(0.9))
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .onEnded { _ in
                            HapticManager.shared.triggerSelectionTick()
                            isDialActive = true
                        }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.4)))
    }
    
    // MARK: - Expanded Fine-Grained Zoom Dial Wheel
    private var expandedDialWheel: some View {
        VStack(spacing: 6) {
            // Selected Zoom Label Badge
            Text(String(format: "%.1fx", zoomFactor))
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.7)))
            
            // Interactive Tick Marks Dial
            GeometryReader { geo in
                let center = geo.size.width / 2
                
                ZStack {
                    // Tick marks from 0.5 to 5.0
                    HStack(spacing: 8) {
                        ForEach(5...50, id: \.self) { val in
                            let currentVal = CGFloat(val) / 10.0
                            let isMajor = (val % 10 == 0) || (val == 5)
                            
                            Rectangle()
                                .fill(isMajor ? Color.yellow : Color.white.opacity(0.4))
                                .frame(width: isMajor ? 2.0 : 1.0, height: isMajor ? 20.0 : 10.0)
                        }
                    }
                    .offset(x: -((zoomFactor - 0.5) / 4.5) * 360.0 + (center / 2))
                    
                    // Center Reticle
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 2.5, height: 26)
                        .shadow(color: .black, radius: 2)
                }
                .frame(width: geo.size.width, height: 40)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let delta = -value.translation.width / 220.0
                            let newZoom = max(0.5, min(5.0, zoomFactor + delta))
                            zoomFactor = newZoom
                            onZoomChanged(newZoom)
                            
                            // Haptic tick on each 0.1x step
                            let step = Int(newZoom * 10)
                            if step != lastReportedZoomStep {
                                lastReportedZoomStep = step
                                HapticManager.shared.triggerSelectionTick()
                            }
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    isDialActive = false
                                }
                            }
                        }
                )
            }
            .frame(height: 40)
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.55)))
    }
    
    private func isSelected(preset: CGFloat) -> Bool {
        return abs(zoomFactor - preset) < 0.15
    }
    
    private func formatPresetText(_ preset: CGFloat) -> String {
        if preset == 0.5 {
            return ".5"
        } else if preset.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(preset))"
        } else {
            return String(format: "%.1f", preset)
        }
    }
}
