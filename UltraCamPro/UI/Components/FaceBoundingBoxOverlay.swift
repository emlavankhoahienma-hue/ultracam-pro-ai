import SwiftUI

public struct FaceBoundingBoxOverlay: View {
    public let faces: [TrackedFace]
    public let viewSize: CGSize
    
    @State private var pulseScale: CGFloat = 1.0
    
    public init(faces: [TrackedFace], viewSize: CGSize) {
        self.faces = faces
        self.viewSize = viewSize
    }
    
    public var body: some View {
        ZStack {
            ForEach(faces) { face in
                let rect = convertVisionRect(face.boundingBox, viewSize: viewSize)
                
                ZStack(alignment: .topLeading) {
                    // Corner Brackets Shape
                    CameraFocusBracketShape()
                        .stroke(Color.yellow, lineWidth: face.isPrimary ? 2.5 : 1.5)
                        .frame(width: rect.width, height: rect.height)
                        .scaleEffect(face.isPrimary ? pulseScale : 1.0)
                    
                    // AI Focus Lock Badge
                    if face.isPrimary {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 6, height: 6)
                            Text("AI FOCUS 0ms")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow)
                        .cornerRadius(4)
                        .offset(x: 0, y: -24)
                    }
                }
                .position(x: rect.midX, y: rect.midY)
                .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: rect)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.04
            }
        }
    }
    
    // Convert Vision normalized coordinates (origin at bottom-left) to SwiftUI View coordinates (origin at top-left)
    private func convertVisionRect(_ visionRect: CGRect, viewSize: CGSize) -> CGRect {
        let width = visionRect.width * viewSize.width
        let height = visionRect.height * viewSize.height
        let x = visionRect.origin.x * viewSize.width
        let y = (1.0 - visionRect.origin.y - visionRect.height) * viewSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Custom Corner Brackets Shape
public struct CameraFocusBracketShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let bracketLength: CGFloat = min(rect.width, rect.height) * 0.22
        
        // Top-Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + bracketLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + bracketLength, y: rect.minY))
        
        // Top-Right
        path.move(to: CGPoint(x: rect.maxX - bracketLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bracketLength))
        
        // Bottom-Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - bracketLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - bracketLength, y: rect.maxY))
        
        // Bottom-Left
        path.move(to: CGPoint(x: rect.minX + bracketLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - bracketLength))
        
        return path
    }
}
