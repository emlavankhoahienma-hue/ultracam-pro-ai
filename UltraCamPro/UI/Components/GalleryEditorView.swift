import SwiftUI
import Photos

public struct GalleryEditorView: View {
    public let initialImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var isEraserMode: Bool = true
    @State private var isProcessing: Bool = false
    @State private var brushLines: [Line] = []
    @State private var currentLine: Line = Line(points: [], lineWidth: 28)
    @State private var brushSize: CGFloat = 28.0
    @State private var showSaveSuccess: Bool = false
    @State private var displayRect: CGRect = .zero
    
    public struct Line: Identifiable {
        public let id = UUID()
        public var points: [CGPoint] // Stored in normalized [0, 1] coordinates relative to image
        public var lineWidth: CGFloat
    }
    
    public init(initialImage: UIImage?) {
        self.initialImage = initialImage
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Main Photo Canvas
                    GeometryReader { geo in
                        let viewSize = geo.size
                        
                        ZStack {
                            if let img = currentImage {
                                let imgSize = img.size
                                let fittedRect = calculateAspectFitRect(imageSize: imgSize, containerSize: viewSize)
                                
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: viewSize.width, height: viewSize.height)
                                
                                // Interactive Brush Overlay Canvas
                                if isEraserMode {
                                    Canvas { context, size in
                                        // Draw existing lines
                                        for line in brushLines {
                                            var path = Path()
                                            if let first = line.points.first {
                                                path.move(to: denormalizePoint(first, in: fittedRect))
                                                for pt in line.points.dropFirst() {
                                                    path.addLine(to: denormalizePoint(pt, in: fittedRect))
                                                }
                                            }
                                            context.stroke(
                                                path,
                                                with: .color(Color.yellow.opacity(0.65)),
                                                style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round)
                                            )
                                        }
                                        
                                        // Draw active line
                                        var currentPath = Path()
                                        if let first = currentLine.points.first {
                                            currentPath.move(to: denormalizePoint(first, in: fittedRect))
                                            for pt in currentLine.points.dropFirst() {
                                                currentPath.addLine(to: denormalizePoint(pt, in: fittedRect))
                                            }
                                        }
                                        context.stroke(
                                            currentPath,
                                            with: .color(Color.yellow.opacity(0.7)),
                                            style: StrokeStyle(lineWidth: currentLine.lineWidth, lineCap: .round, lineJoin: .round)
                                        )
                                    }
                                    .frame(width: viewSize.width, height: viewSize.height)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { val in
                                                let normPt = normalizePoint(val.location, in: fittedRect)
                                                currentLine.points.append(normPt)
                                                currentLine.lineWidth = brushSize
                                            }
                                            .onEnded { _ in
                                                if !currentLine.points.isEmpty {
                                                    brushLines.append(currentLine)
                                                    currentLine = Line(points: [], lineWidth: brushSize)
                                                }
                                            }
                                    )
                                }
                            } else {
                                Text("No photo captured yet")
                                    .foregroundColor(.gray)
                            }
                            
                            if isProcessing {
                                ZStack {
                                    Color.black.opacity(0.7)
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                                            .scaleEffect(1.4)
                                        Text("AI Inpainting Texture...")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .frame(width: 220, height: 120)
                                .cornerRadius(16)
                            }
                        }
                    }
                    
                    // MARK: - Brush Controls & Actions Toolbar
                    VStack(spacing: 12) {
                        // Brush Size Slider
                        HStack(spacing: 12) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                            
                            Slider(value: $brushSize, in: 10...60, step: 2)
                                .accentColor(.yellow)
                            
                            Text("\(Int(brushSize))pt")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 40)
                        }
                        .padding(.horizontal, 20)
                        
                        // Action Buttons Row
                        HStack(spacing: 16) {
                            // Undo Brush Button
                            Button(action: {
                                HapticManager.shared.triggerLightTap()
                                if !brushLines.isEmpty {
                                    brushLines.removeLast()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Undo")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(brushLines.isEmpty ? .gray : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(20)
                            }
                            .disabled(brushLines.isEmpty)
                            
                            // Clear Brush Button
                            Button(action: {
                                HapticManager.shared.triggerLightTap()
                                brushLines.removeAll()
                            }) {
                                Text("Clear")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(brushLines.isEmpty ? .gray : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(20)
                            }
                            .disabled(brushLines.isEmpty)
                            
                            Spacer()
                            
                            // Execute AI Erase Button
                            Button(action: executeEraserInpainting) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("Erase Object")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(brushLines.isEmpty ? Color.gray : Color.yellow)
                                .cornerRadius(20)
                            }
                            .disabled(brushLines.isEmpty || isProcessing)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.9))
                }
            }
            .navigationTitle("AI Magic Eraser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveEditedImage) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.yellow)
                    }
                }
            }
            .onAppear {
                self.currentImage = initialImage
                self.originalImage = initialImage
            }
            .alert(isPresented: $showSaveSuccess) {
                Alert(title: Text("Saved"), message: Text("Photo saved to your Photos library."), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Inpainting Execution
    private func executeEraserInpainting() {
        guard let sourceImage = currentImage else { return }
        isProcessing = true
        HapticManager.shared.triggerLightTap()
        
        let maskImage = generateAccurateBitmapMask(sourceSize: sourceImage.size)
        
        AIEraser.shared.removeObject(from: sourceImage, mask: maskImage) { result in
            self.isProcessing = false
            if let result = result {
                HapticManager.shared.triggerSuccess()
                self.currentImage = result
                self.brushLines.removeAll()
            } else {
                HapticManager.shared.triggerWarning()
            }
        }
    }
    
    // MARK: - Pixel-Accurate Mask Generation
    private func generateAccurateBitmapMask(sourceSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(sourceSize, true, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        
        // Black background
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: sourceSize))
        
        // Draw white strokes mapped to source image pixels
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        let scaleFactor = max(sourceSize.width, sourceSize.height) / 400.0
        
        for line in brushLines {
            ctx.setLineWidth(line.lineWidth * scaleFactor)
            if let first = line.points.first {
                ctx.move(to: CGPoint(x: first.x * sourceSize.width, y: first.y * sourceSize.height))
                for pt in line.points.dropFirst() {
                    ctx.addLine(to: CGPoint(x: pt.x * sourceSize.width, y: pt.y * sourceSize.height))
                }
                ctx.strokePath()
            }
        }
        
        let mask = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return mask
    }
    
    // MARK: - Aspect Fit Coordinate Helpers
    private func calculateAspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let aspectWidth = containerSize.width / imageSize.width
        let aspectHeight = containerSize.height / imageSize.height
        let scale = min(aspectWidth, aspectHeight)
        
        let targetWidth = imageSize.width * scale
        let targetHeight = imageSize.height * scale
        let targetX = (containerSize.width - targetWidth) / 2.0
        let targetY = (containerSize.height - targetHeight) / 2.0
        
        return CGRect(x: targetX, y: targetY, width: targetWidth, height: targetHeight)
    }
    
    private func normalizePoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else { return .zero }
        let clampedX = max(rect.minX, min(rect.maxX, point.x))
        let clampedY = max(rect.minY, min(rect.maxY, point.y))
        return CGPoint(
            x: (clampedX - rect.minX) / rect.width,
            y: (clampedY - rect.minY) / rect.height
        )
    }
    
    private func denormalizePoint(_ normPoint: CGPoint, in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: rect.minX + normPoint.x * rect.width,
            y: rect.minY + normPoint.y * rect.height
        )
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
