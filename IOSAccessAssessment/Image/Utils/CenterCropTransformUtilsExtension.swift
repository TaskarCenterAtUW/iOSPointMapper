//
//  CenterCropTransformUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 10/27/25.
//

import UIKit

/**
    Utility struct for center crop transformations.
    Contains methods to perform center-crop with aspect-fit resizing, to get the transform, process a CIImage, or process a CGRect.
    Also contains methods to revert the center-crop transformation.
 */
extension CenterCropTransformUtils {
    /**
     Center-crop with aspect-fit resizing.
     
     This function resizes a CIImage to match the specified size by:
        - First, resizing the image to match the smaller dimension while maintaining the aspect ratio.
        - Then, cropping the image to the specified size while centering it.
     It thus gets the largest possible subregion of the image that fits within the target size without distortion.
     */
    static func centerCropAspectFit(_ image: CIImage, to size: CGSize) -> CIImage {
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
        let transformedImage = image.transformed(by: transform)
        let croppedImage = transformedImage.cropped(to: CGRect(origin: .zero, size: size))
        return croppedImage
    }
    
    static func centerCropAspectFitTransform(imageSize: CGSize, to size: CGSize) -> CGAffineTransform {
        let sourceAspect = imageSize.width / imageSize.height
        let destAspect = size.width / size.height
        
        var transform: CGAffineTransform = .identity
        if sourceAspect > destAspect {
            let scale = size.height / imageSize.height
            let newWidth = imageSize.width * scale
            let xOffset = (size.width - newWidth) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: 0)
        } else {
            let scale = size.width / imageSize.width
            let newHeight = imageSize.height * scale
            let yOffset = (size.height - newHeight) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: 0, y: yOffset / scale)
        }
        return transform
    }
    
    /**
     This reverse function attempts to revert the effect of `centerCropAspectFit`.
        It takes the cropped and resized image, the target size it was resized to, and the original size before resizing and cropping.
        It calculates the necessary scaling and translation to restore the image to its original aspect ratio and size.
     
     - WARNING:
     Do not use this function for images without color space or with alpha channels, as it may produce incorrect results.
     */
    static func revertCenterCropAspectFit(
        _ image: CIImage, from originalSize: CGSize
    ) -> CIImage {
        let sourceAspect = image.extent.width / image.extent.height
        let destAspect = originalSize.width / originalSize.height
        
        var transform: CGAffineTransform = .identity
        var newWidth: CGFloat = originalSize.width
        var newHeight: CGFloat = originalSize.height
        if sourceAspect < destAspect {
            let scale = originalSize.height / image.extent.height
            newWidth = originalSize.width
            let xOffset = (newWidth - image.extent.width * scale) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: 0)
        } else {
            let scale = originalSize.width / image.extent.width
            newHeight = originalSize.height
            let yOffset = (newHeight - image.extent.height * scale) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: 0, y: yOffset / scale)
        }
        let transformedImage = image.samplingNearest().transformed(by: transform)
        let canvas = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        let background = CIImage(color: .clear).cropped(to: canvas)
        let composed = transformedImage.composited(over: background)
        return composed
    }
    
    /**
     This reverse function attempts to revert the effect of `centerCropAspectFit`.
        It takes the cropped and resized image, the target size it was resized to, and the original size before resizing and cropping.
        It calculates the necessary scaling and translation to restore the image to its original aspect ratio and size.
        It renders the final image on a provided pixel buffer
     */
    static func revertCenterCropAspectFit(
        _ image: CIImage, from originalSize: CGSize,
        to pixelBuffer: CVPixelBuffer,
        context: CIContext, colorSpace: CGColorSpace? = nil
    ) {
        let sourceAspect = image.extent.width / image.extent.height
        let destAspect = originalSize.width / originalSize.height
        
        var transform: CGAffineTransform = .identity
        var newWidth: CGFloat = originalSize.width
        var newHeight: CGFloat = originalSize.height
        if sourceAspect < destAspect {
            let scale = originalSize.height / image.extent.height
            newWidth = originalSize.width
            let xOffset = (newWidth - image.extent.width * scale) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: 0)
        } else {
            let scale = originalSize.width / image.extent.width
            newHeight = originalSize.height
            let yOffset = (newHeight - image.extent.height * scale) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: 0, y: yOffset / scale)
        }
        let transformedImage = image.samplingNearest().transformed(by: transform)
        let canvas = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        context.render(transformedImage, to: pixelBuffer, bounds: canvas, colorSpace: colorSpace)
    }
    
    /**
     This function returns the transformation to revert the effect of `centerCropAspectFit`.
     */
    static func revertCenterCropAspectFitTransform(imageSize: CGSize, from originalSize: CGSize) -> CGAffineTransform {
        let sourceAspect = imageSize.width / imageSize.height
        let destAspect = originalSize.width / originalSize.height
        
        var transform: CGAffineTransform = .identity
        if sourceAspect < destAspect {
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
    
    /**
     This function computes the bounding rectangle of the center-cropped area within the original image that corresponds to the specified size after center-crop with aspect-fit resizing.
     */
    static func centerCropAspectFitBoundingRect(imageSize: CGSize, to size: CGSize) -> CGRect {
        let sourceAspect = imageSize.width / imageSize.height
        let destAspect = size.width / size.height
        
        var rect: CGRect = .zero
        var scale: CGFloat = 1.0
        var xOffset: CGFloat = 0.0
        var yOffset: CGFloat = 0.0
        if sourceAspect > destAspect {
            scale = imageSize.height / size.height
            xOffset = (imageSize.width - (size.width * scale)) / 2
        } else {
            scale = imageSize.width / size.width
            yOffset = (imageSize.height - (size.height * scale)) / 2
        }
        rect.size = CGSize(width: size.width * scale, height: size.height * scale)
        rect.origin = CGPoint(x: xOffset, y: yOffset)
        return rect
    }
    
    /**
     This function reverts the effect of `centerCropAspectFit` on a CGRect.
        It computes the original rectangle in the source image that corresponds to the given rectangle in the cropped and resized image.
     */
    static func revertCenterCropAspectFitRect(_ rect: CGRect, imageSize: CGSize, from originalSize: CGSize) -> CGRect {
        let sourceAspect = imageSize.width / imageSize.height
        let destAspect = originalSize.width / originalSize.height
        
        var transform: CGAffineTransform = .identity
        if sourceAspect < destAspect {
            // Image was cropped horizontally because original is wider
            let scale = imageSize.height / originalSize.height
            let newImageSize = CGSize(width: imageSize.width / scale, height: imageSize.height / scale)
            let xOffset = (originalSize.width - newImageSize.width) / (2 * originalSize.width)
            let widthScale = newImageSize.width / originalSize.width
            transform = CGAffineTransform(scaleX: widthScale, y: 1)
                .translatedBy(x: xOffset / widthScale, y: 0)
        } else {
            // Image was cropped vertically because original is taller
            let scale = imageSize.width / originalSize.width
            let newImageSize = CGSize(width: imageSize.width / scale, height: imageSize.height / scale)
            let yOffset = (originalSize.height - newImageSize.height) / (2 * originalSize.height)
            let heightScale = newImageSize.height / originalSize.height
            transform = CGAffineTransform(scaleX: 1, y: heightScale)
                .translatedBy(x: 0, y: yOffset / heightScale)
        }
        let revertedRect = rect.applying(transform)
        return revertedRect
    }
    
    /**
     This function returns the transformation to reverse the effect of `centerCropAspectFit` on normalized co-ordinates.
     */
    static func revertCenterCropAspectFitNormalizedTransform(imageSize: CGSize, from originalSize: CGSize) -> CGAffineTransform {
        let sourceAspect = imageSize.width / imageSize.height
        let destAspect = originalSize.width / originalSize.height
        
        var transform: CGAffineTransform = .identity
        if sourceAspect < destAspect {
            // Image was cropped horizontally because original is wider
            let scale = imageSize.height / originalSize.height
            let newImageSize = CGSize(width: imageSize.width / scale, height: imageSize.height / scale)
            let xOffset = (originalSize.width - newImageSize.width) / (2 * originalSize.width)
            let widthScale = newImageSize.width / originalSize.width
            transform = CGAffineTransform(scaleX: widthScale, y: 1)
                .translatedBy(x: xOffset / widthScale, y: 0)
        } else {
            // Image was cropped vertically because original is taller
            let scale = imageSize.width / originalSize.width
            let newImageSize = CGSize(width: imageSize.width / scale, height: imageSize.height / scale)
            let yOffset = (originalSize.height - newImageSize.height) / (2 * originalSize.height)
            let heightScale = newImageSize.height / originalSize.height
            transform = CGAffineTransform(scaleX: 1, y: heightScale)
                .translatedBy(x: 0, y: yOffset / heightScale)
        }
        return transform
    }
}
