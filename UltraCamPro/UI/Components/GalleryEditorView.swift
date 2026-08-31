import SwiftUI
import Photos

public struct GalleryEditorView: View {
    public let initialImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var isEraserMode: Bool = false
    @State private var isProcessing: Bool = false
    @State private var brushLines: [Line] = []
    @State private var currentLine: Line = Line(points: [], lineWidth: 24)
    @State private var showSaveSuccess: Bool = false
    @State private var compareProgress: Double = 1.0 // 0.0: Original, 1.0: Inpainted
    
    public struct Line {
        var points: [CGPoint]
        var lineWidth: CGFloat
    }
    
    public init(initialImage: UIImage?) {
        self.initialImage = initialImage
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Image Display Canvas
                    GeometryReader { geo in
                        ZStack {
                            if let img = currentImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                
                                // Brush Drawing Canvas for AI Eraser
                                if isEraserMode {
                                    Canvas { context, size in
                                        for line in brushLines {
                                            var path = Path()
                                            if let first = line.points.first {
                                                path.move(to: first)
                                                for pt in line.points.dropFirst() {
                                                    path.addLine(to: pt)
                                                }
                                            }
                                            context.stroke(path, with: .color(Color.yellow.opacity(0.65)), lineWidth: line.lineWidth)
                                        }
                                        
                                        var currentPath = Path()
                                        if let first = currentLine.points.first {
                                            currentPath.move(to: first)
                                            for pt in currentLine.points.dropFirst() {
                                                currentPath.addLine(to: pt)
                                            }
                                        }
                                        context.stroke(currentPath, with: .color(Color.yellow.opacity(0.65)), lineWidth: currentLine.lineWidth)
                                    }
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { val in
                                                currentLine.points.append(val.location)
                                            }
                                            .onEnded { _ in
                                                brushLines.append(currentLine)
                                                currentLine = Line(points: [], lineWidth: 24)
                                            }
                                    )
                                }
                            } else {
                                Text("No photo available")
                                    .foregroundColor(.gray)
                            }
                            
                            if isProcessing {
                                ZStack {
                                    Color.black.opacity(0.6)
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                                            .scaleEffect(1.5)
                                        Text("AI Magic Inpainting...")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .cornerRadius(16)
                                .frame(width: 200, height: 120)
                            }
                        }
                    }
                    
                    // Bottom Control Toolbar
                    HStack(spacing: 20) {
                        // Magic Eraser Toggle Button
                        Button(action: {
                            HapticManager.shared.triggerRigidSnap()
                            withAnimation {
                                isEraserMode.toggle()
                                if !isEraserMode {
                                    brushLines.removeAll()
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isEraserMode ? "paintbrush.fill" : "sparkles")
                                Text(isEraserMode ? "Brush Active" : "AI Magic Eraser")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isEraserMode ? .black : .yellow)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isEraserMode ? Color.yellow : Color.white.opacity(0.15))
                            .cornerRadius(20)
                        }
                        
                        // Execute Erase Button
                        if isEraserMode && !brushLines.isEmpty {
                            Button(action: executeEraserInpainting) {
                                HStack(spacing: 4) {
                                    Image(systemName: "wand.and.stars")
                                    Text("Erase Object")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(20)
                            }
                        }
                        
                        Spacer()
                        
                        // Save Button
                        Button(action: saveEditedImage) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.85))
                }
            }
            .navigationTitle("Photo Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                self.currentImage = initialImage
                self.originalImage = initialImage
            }
            .alert(isPresented: $showSaveSuccess) {
                Alert(title: Text("Saved"), message: Text("Photo saved to Photo Library successfully."), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Execute Inpainting
    private func executeEraserInpainting() {
        guard let sourceImage = currentImage else { return }
        isProcessing = true
        HapticManager.shared.triggerLightTap()
        
        let maskImage = generateMaskImage(size: sourceImage.size)
        
        AIEraser.shared.removeObject(from: sourceImage, mask: maskImage) { result in
            self.isProcessing = false
            if let result = result {
                HapticManager.shared.triggerSuccess()
                self.currentImage = result
                self.brushLines.removeAll()
                self.isEraserMode = false
            } else {
                HapticManager.shared.triggerWarning()
            }
        }
    }
    
    private func generateMaskImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        for line in brushLines {
            ctx.setLineWidth(line.lineWidth * 2.0)
            if let first = line.points.first {
                ctx.move(to: first)
                for pt in line.points.dropFirst() {
                    ctx.addLine(to: pt)
                }
                ctx.strokePath()
            }
        }
        
        let mask = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return mask
    }
    
    private func saveEditedImage() {
        guard let img = currentImage else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: img)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    HapticManager.shared.triggerSuccess()
                    self.showSaveSuccess = true
                }
            }
        }
    }
}
