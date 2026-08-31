import SwiftUI

public struct CameraModeSelectorView: View {
    @Binding public var selectedMode: CameraMode
    public let onModeChanged: (CameraMode) -> Void
    
    public init(selectedMode: Binding<CameraMode>, onModeChanged: @escaping (CameraMode) -> Void) {
        self._selectedMode = selectedMode
        self.onModeChanged = onModeChanged
    }
    
    public var body: some View {
        HStack(spacing: 20) {
            ForEach(CameraMode.allCases) { mode in
                Button(action: {
                    HapticManager.shared.triggerSelectionTick()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedMode = mode
                    }
                    onModeChanged(mode)
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: selectedMode == mode ? .bold : .semibold, design: .rounded))
                        .foregroundColor(selectedMode == mode ? .yellow : .white.opacity(0.65))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
