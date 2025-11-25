//
//  CIImageUtils.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/27/24.
//

import UIKit
import MetalKit

enum CIImageUtilsError: Error, LocalizedError {
    case pixelBufferCreationError
    case segmentationTextureError
    
    var errorDescription: String? {
        switch self {
        case .pixelBufferCreationError:
            return "Failed to create pixel buffer from CIImage."
        case .segmentationTextureError:
            return "Failed to create segmentation texture."
        }
    }
}

extension CIImage {
    func croppedToCenter(size: CGSize) -> CIImage {
        let x = (extent.width - size.width) / 2
        let y = (extent.height - size.height) / 2
        let cropRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        let croppedImage = cropped(to: cropRect)
        
        let centeredImage = croppedImage.transformed(by: CGAffineTransform(translationX: -x, y: -y))
        return centeredImage
    }
    
    /// Returns a resized image.
    func resized(to size: CGSize) -> CIImage {
        let outputScaleX = size.width / extent.width
        let outputScaleY = size.height / extent.height
        var outputImage = self.transformed(by: CGAffineTransform(scaleX: outputScaleX, y: outputScaleY))
        outputImage = outputImage.transformed(
            by: CGAffineTransform(translationX: -outputImage.extent.origin.x, y: -outputImage.extent.origin.y)
        )
        return outputImage
    }
}

/**
    Extensions for converting CIImage to CVPixelBuffer.
 */
extension CIImage {
    func toPixelBuffer(
        context: CIContext, pixelFormatType: OSType = kCVPixelFormatType_32BGRA, colorSpace: CGColorSpace? = nil
    ) throws -> CVPixelBuffer {
        let width = Int(self.extent.width)
        let height = Int(self.extent.height)
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormatType,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw CIImageUtilsError.pixelBufferCreationError
        }
        context.render(self, to: buffer, bounds: self.extent, colorSpace: colorSpace)
        return buffer
    }
    
    func toPixelBuffer(
        context: CIContext, pixelBufferPool: CVPixelBufferPool, colorSpace: CGColorSpace? = nil
    ) throws -> CVPixelBuffer {
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            throw CIImageUtilsError.pixelBufferCreationError
        }
        context.render(self, to: pixelBuffer, bounds: self.extent, colorSpace: colorSpace)
        return pixelBuffer
    }
}

/**
 Extensions for converting CIImage to MTLTexture.
 */
extension CIImage {
    func toMTLTexture(
        device: MTLDevice, commandBuffer: MTLCommandBuffer,
        pixelFormat: MTLPixelFormat,
        contextNoColorSpace: CIContext
    ) throws -> MTLTexture {
        let mtlDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(self.extent.width), height: Int(self.extent.height),
            mipmapped: false
        )
        mtlDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let segmentationTexture = device.makeTexture(descriptor: mtlDescriptor) else {
            throw CIImageUtilsError.segmentationTextureError
        }
        /// Fixing mirroring issues by orienting the image before rendering to texture
        let segmentationImageOriented = self.oriented(.downMirrored)
        contextNoColorSpace.render(
            segmentationImageOriented,
            to: segmentationTexture,
            commandBuffer: commandBuffer,
            bounds: self.extent,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
        return segmentationTexture
    }
    
    func toMTLTexture(
        textureLoader: MTKTextureLoader,
        context: CIContext
    ) throws -> MTLTexture {
        let mtlDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: Int(self.extent.width), height: Int(self.extent.height),
            mipmapped: false
        )
        mtlDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let cgImage = context.createCGImage(self, from: self.extent) else {
            throw CIImageUtilsError.segmentationTextureError
        }
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        return try textureLoader.newTexture(cgImage: cgImage, options: options)
    }
}

/**
 Legacy functions for resizing and cropping CIImage.
 */
struct CIImageUtils {
    /**
     This function resizes a CIImage to match the specified size by:
        - First, resizing the image to match the smaller dimension while maintaining the aspect ratio.
        - Then, cropping the image to the specified size while centering it.
     */
    static func resizeWithAspectThenCrop(_ image: CIImage, to size: CGSize) -> CIImage {
        let sourceAspect = image.extent.width / image.extent.height
        let destAspect = size.width / size.height
        
        var transform: CGAffineTransform = .identity
        if sourceAspect > destAspect {
            let scale = size.height / image.extent.height
            let newWidth = image.extent.width * scale
            let xOffset = (size.width - newWidth) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: 0)
        } else {
            let scale = size.width / image.extent.width
            let newHeight = image.extent.height * scale
            let yOffset = (size.height - newHeight) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: 0, y: yOffset / scale)
        }
        let newImage = image.transformed(by: transform)
        let croppedImage = newImage.cropped(to: CGRect(origin: .zero, size: size))
        return croppedImage
    }
    
    /**
     This function returns the transformation to revert the effect of `resizeWithAspectThenCrop`.
     */
    static func transformRevertResizeWithAspectThenCrop(imageSize: CGSize, from originalSize: CGSize) -> CGAffineTransform {
        let sourceAspect = imageSize.width / imageSize.height
        let originalAspect = originalSize.width / originalSize.height
        
        var transform: CGAffineTransform = .identity
        if sourceAspect < originalAspect {
            let scale = originalSize.height / imageSize.height
            let newWidth = imageSize.width * scale
            let xOffset = (originalSize.width - newWidth) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: 0)
        } else {
            let scale = originalSize.width / imageSize.width
            let newHeight = imageSize.height * scale
            let yOffset = (originalSize.height - newHeight) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: 0, y: yOffset / scale)
        }
        return transform
    }
}
