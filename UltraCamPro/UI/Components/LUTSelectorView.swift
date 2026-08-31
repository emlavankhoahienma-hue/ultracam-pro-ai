import SwiftUI

public struct LUTSelectorView: View {
    @ObservedObject public var lutEngine: LUTEngine
    public let onSelect: (LUTPreset) -> Void
    
    public init(lutEngine: LUTEngine, onSelect: @escaping (LUTPreset) -> Void) {
        self.lutEngine = lutEngine
        self.onSelect = onSelect
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LUTPreset.allCases) { preset in
                    Button(action: {
                        HapticManager.shared.triggerSelectionTick()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            lutEngine.selectPreset(preset)
                        }
                        onSelect(preset)
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(lutEngine.activePreset == preset ? Color.yellow.opacity(0.25) : Color.black.opacity(0.5))
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        Circle()
                                            .stroke(lutEngine.activePreset == preset ? Color.yellow : Color.white.opacity(0.3), lineWidth: 1.8)
                                    )
                                
                                Text(preset.shortBadge)
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(lutEngine.activePreset == preset ? .yellow : .white)
                            }
                            
                            Text(preset.displayName)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(lutEngine.activePreset == preset ? .yellow : .white.opacity(0.8))
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}
