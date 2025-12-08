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
 Supporting enum for CIImage to MTLTexture conversion.
 */
enum CIImageToMTLTextureOrientation: Sendable {
    case cICanonical
    case metalTopLeft
}

/**
 Extensions for converting CIImage to MTLTexture.
 */
extension CIImage {
    /**
        Converts the CIImage to a MTLTexture using the provided device, command buffer, pixel format, CIContext, and color space.
     
        Performs a direct conversion by rendering the CIImage into a newly created MTLTexture.
     
        - WARNING:
        This method has a vertical mirroring issue, thanks to the way MTLTexture coordinates conflict with CIImage coordinates.
        For now, the caller has the responsibility of deciding whether it wants to follow CIImage's coordinate system or MTLTexture's coordinate system.
        This will be expressed using the custom enum `CIImageToMTLTextureOrientation`.
     */
    func toMTLTexture(
        device: MTLDevice, commandBuffer: MTLCommandBuffer,
        pixelFormat: MTLPixelFormat,
        context: CIContext, colorSpace: CGColorSpace,
        cIImageToMTLTextureOrientation: CIImageToMTLTextureOrientation = .cICanonical
    ) throws -> MTLTexture {
        let mtlDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(self.extent.width), height: Int(self.extent.height),
            mipmapped: false
        )
        /// TODO: Make this configurable if needed
        mtlDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: mtlDescriptor) else {
            throw CIImageUtilsError.segmentationTextureError
        }
        let imageOriented: CIImage
        switch cIImageToMTLTextureOrientation {
        case .cICanonical:
            imageOriented = self
        case .metalTopLeft:
            imageOriented = self
                .transformed(by: CGAffineTransform(scaleX: 1, y: -1))
                .transformed(by: CGAffineTransform(translationX: 0, y: self.extent.height))
        }
        context.render(
            imageOriented,
            to: texture,
            commandBuffer: commandBuffer,
            bounds: self.extent,
            colorSpace: colorSpace
        )
        return texture
    }
    
    /**
        Converts the CIImage to a MTLTexture using the provided MTKTextureLoader and CIContext.
     
        This method creates a CGImage from the CIImage and then uses the texture loader to create the MTLTexture.
        
     - WARNING:
        Seems to have mirroring issues.
     */
    func toMTLTexture(
        textureLoader: MTKTextureLoader,
        context: CIContext
    ) throws -> MTLTexture {
        guard let cgImage = context.createCGImage(self, from: self.extent) else {
            throw CIImageUtilsError.segmentationTextureError
        }
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        return try textureLoader.newTexture(cgImage: cgImage, options: options)
    }
}
