//
//  CenterCropTransformUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/9/26.
//

import Metal
import MetalKit

enum CenterCropTransformUtilsError: Error, LocalizedError {
    case metalInitializationFailed
    case invalidInputImage
    case textureCreationFailed
    case metalPipelineCreationError
    case outputImageCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        case .invalidInputImage:
            return "The input image is invalid."
        case .textureCreationFailed:
            return "Failed to create Metal textures."
        case .metalPipelineCreationError:
            return "Failed to create Metal compute pipeline."
        case .outputImageCreationFailed:
            return "Failed to create output CIImage from Metal texture."
        }
    }
}

struct CenterCropTransformUtils {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw CenterCropTransformUtilsError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    }
    
    func revertCenterCropAspectFit(_ image: CIImage, to destSize: CGSize) -> CIImage {
        let sourceSize = image.extent.size
        let sourceAspect = sourceSize.width / sourceSize.height
        let destAspect = destSize.width / destSize.height
        
        let scale: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        if sourceAspect < destAspect {
            scale = destSize.height / sourceSize.height
            let scaledWidth = sourceSize.width * scale
            offsetX = (destSize.width - scaledWidth) / 2
        } else {
            scale = destSize.width / sourceSize.width
            let scaledHeight = sourceSize.height * scale
            offsetY = (destSize.height - scaledHeight) / 2
        }
        return image
    }
}
