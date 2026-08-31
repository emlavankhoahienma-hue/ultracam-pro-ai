import SwiftUI

public struct ZoomDialView: View {
    @Binding public var zoomFactor: CGFloat
    public let onZoomChanged: (CGFloat) -> Void
    
    private let zoomPresets: [CGFloat] = [0.5, 1.0, 2.0, 3.0, 5.0]
    
    public init(zoomFactor: Binding<CGFloat>, onZoomChanged: @escaping (CGFloat) -> Void) {
        self._zoomFactor = zoomFactor
        self.onZoomChanged = onZoomChanged
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            ForEach(zoomPresets, id: \.self) { preset in
                Button(action: {
                    HapticManager.shared.triggerRigidSnap()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        zoomFactor = preset
                    }
                    onZoomChanged(preset)
                }) {
                    ZStack {
                        if isSelected(preset: preset) {
                            Circle()
                                .fill(Color.black.opacity(0.75))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.yellow, lineWidth: 1.8)
                                )
                        } else {
                            Circle()
                                .fill(Color.black.opacity(0.25))
                                .frame(width: 32, height: 32)
                        }
                        
                        Text(formatPresetText(preset))
                            .font(.system(size: isSelected(preset: preset) ? 13 : 11, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected(preset: preset) ? .yellow : .white.opacity(0.85))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
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
