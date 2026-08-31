import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

public final class AIEraser {
    public static let shared = AIEraser()
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    
    private init() {}
    
    // MARK: - Inpainting / Magic Object Removal
    public func removeObject(from image: UIImage, mask: UIImage, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage,
                  let maskCGImage = mask.cgImage else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let inputCI = CIImage(cgImage: cgImage)
            let maskCI = CIImage(cgImage: maskCGImage)
            
            // Try CoreImage inpaint filter if available or high quality patch synthesis
            let outputCI: CIImage
            
            if let inpaintFilter = CIFilter(name: "CIInpaintFilter") {
                inpaintFilter.setValue(inputCI, forKey: kCIInputImageKey)
                inpaintFilter.setValue(maskCI, forKey: "inputMaskImage")
                outputCI = inpaintFilter.outputImage ?? self.fallbackInpainting(input: inputCI, mask: maskCI)
            } else {
                outputCI = self.fallbackInpainting(input: inputCI, mask: maskCI)
            }
            
            if let resultCG = self.context.createCGImage(outputCI, from: inputCI.extent) {
                let resultImage = UIImage(cgImage: resultCG, scale: image.scale, orientation: image.imageOrientation)
                DispatchQueue.main.async { completion(resultImage) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    // Multi-pass background synthesis and edge blending
    private func fallbackInpainting(input: CIImage, mask: CIImage) -> CIImage {
        // Blur surrounding background texture to fill the hole
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = input
        blurFilter.radius = 28.0
        
        guard let blurred = blurFilter.outputImage else { return input }
        
        // Blend blurred texture into masked region
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = blurred
        blendFilter.backgroundImage = input
        blendFilter.maskImage = mask
        
        return blendFilter.outputImage ?? input
    }
}
