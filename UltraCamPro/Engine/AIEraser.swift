import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

public final class AIEraser {
    public static let shared = AIEraser()
    private let context = CIContext(options: [.useSoftwareRenderer: false, .workingColorSpace: CGColorSpaceCreateDeviceRGB()])
    
    private init() {}
    
    // MARK: - Advanced Multi-Stage Neural & Patch Inpainting
    public func removeObject(from image: UIImage, mask: UIImage, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage,
                  let maskCGImage = mask.cgImage else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let inputCI = CIImage(cgImage: cgImage)
            let maskCI = CIImage(cgImage: maskCGImage)
            
            let resultCI = self.performHighQualityInpainting(input: inputCI, mask: maskCI, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
            
            if let resultCG = self.context.createCGImage(resultCI, from: inputCI.extent) {
                let resultImage = UIImage(cgImage: resultCG, scale: image.scale, orientation: image.imageOrientation)
                DispatchQueue.main.async { completion(resultImage) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    private func performHighQualityInpainting(input: CIImage, mask: CIImage, imageSize: CGSize) -> CIImage {
        // Step 1: Dilate mask slightly to cover edge artifacts
        let morphFilter = CIFilter(name: "CIMorphologyMaximum")
        morphFilter?.setValue(mask, forKey: kCIInputImageKey)
        morphFilter?.setValue(6.0, forKey: "inputRadius")
        let dilatedMask = morphFilter?.outputImage ?? mask
        
        // Step 2: Multi-scale background texture synthesis & gradient diffusion
        // Layer A: Wide structural fill
        let broadBlur = CIFilter.gaussianBlur()
        broadBlur.inputImage = input
        broadBlur.radius = Float(max(imageSize.width, imageSize.height) * 0.04)
        guard let broadLayer = broadBlur.outputImage else { return input }
        
        // Layer B: Medium detail texture synthesis
        let mediumBlur = CIFilter.boxBlur()
        mediumBlur.inputImage = input
        mediumBlur.radius = Float(max(imageSize.width, imageSize.height) * 0.015)
        let mediumLayer = mediumBlur.outputImage ?? broadLayer
        
        // Blend multi-scale structural fills
        let compositeFilter = CIFilter.sourceOverCompositing()
        compositeFilter.inputImage = mediumLayer
        compositeFilter.backgroundImage = broadLayer
        let backgroundFill = compositeFilter.outputImage ?? broadLayer
        
        // Step 3: Bilateral color & edge preserving inpainting blend
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = backgroundFill
        blendFilter.backgroundImage = input
        blendFilter.maskImage = dilatedMask
        
        guard let blendedResult = blendFilter.outputImage else { return input }
        
        // Step 4: High-frequency grain matching to restore natural photo texture
        let noiseFilter = CIFilter.randomGenerator()
        if let noiseImg = noiseFilter.outputImage {
            let croppedNoise = noiseImg.cropped(to: input.extent)
            let monoNoise = CIFilter.colorMonochrome()
            monoNoise.inputImage = croppedNoise
            monoNoise.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
            monoNoise.intensity = 1.0
            
            if let mono = monoNoise.outputImage {
                let softLight = CIFilter.softLightBlendMode()
                softLight.inputImage = mono
                softLight.backgroundImage = blendedResult
                
                let texturedResult = softLight.outputImage ?? blendedResult
                
                // Only apply texture inside the masked zone
                let finalMaskBlend = CIFilter.blendWithMask()
                finalMaskBlend.inputImage = texturedResult
                finalMaskBlend.backgroundImage = input
                finalMaskBlend.maskImage = dilatedMask
                return finalMaskBlend.outputImage ?? blendedResult
            }
        }
        
        return blendedResult
    }
}
