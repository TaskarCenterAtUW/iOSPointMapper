//
//  CVPixelBufferUtils.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/27/24.
//

import UIKit
import Accelerate

struct CVPixelBufferUtils {
    /**
     TODO: Currently, this function is quite hardcoded. For example, it uses a fixed pixel format and attributes.
        It would be better to make it more flexible by allowing the caller to specify the pixel format and attributes.
     */
    static func createPixelBuffer(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_DepthFloat32) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, attrs, &pixelBuffer)
        if status != kCVReturnSuccess {
            print("Failed to create pixel buffer")
            return nil
        }
        return pixelBuffer
    }

    static func createBlankDepthPixelBuffer(targetSize: CGSize) -> CVPixelBuffer? {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        
        let pixelBuffer: CVPixelBuffer? = createPixelBuffer(width: width, height: height, pixelFormat: kCVPixelFormatType_DepthFloat32)
        
        guard let blankPixelBuffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(blankPixelBuffer, [])
        let blankBaseAddress = CVPixelBufferGetBaseAddress(blankPixelBuffer)!
        let blankBufferPointer = blankBaseAddress.bindMemory(to: Float.self, capacity: width * height)
        vDSP_vclr(blankBufferPointer, 1, vDSP_Length(width * height))
        CVPixelBufferUnlockBaseAddress(blankPixelBuffer, [])
        
        return blankPixelBuffer
    }

    /**
     This function extracts unique grayscale values from a pixel buffer,
     gets the indices of these values from Constants.SelectedAccessibilityFeatureConfig.grayscaleValues,
        and returns both the unique values and their corresponding indices.
     
     TODO: The function does more than just extracting unique grayscale values.
     It also returns the indices of these values from Constants.SelectedAccessibilityFeatureConfig.grayscaleValues.
     This can cause confusion. Thus, the index extraction logic should be separated from the unique value extraction.
     */
    static func extractUniqueGrayscaleValues(from pixelBuffer: CVPixelBuffer) -> Set<UInt8> {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return Set<UInt8>()
        }
        
        var buffer = vImage_Buffer(data: baseAddress,
                                     height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)),
                                     width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)),
                                     rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer))
        var histogram = [vImagePixelCount](repeating: 0, count: 256)
        let histogramError = vImageHistogramCalculation_Planar8(&buffer, &histogram, vImage_Flags(kvImageNoFlags))
        guard histogramError == kvImageNoError else { return Set<UInt8>() }
        
        var uniqueValues = Set<UInt8>()
        for i in 0..<histogram.count {
            if histogram[i] > 0 {
                uniqueValues.insert(UInt8(i))
            }
        }
        return uniqueValues
    }
}

/**
 Archived methods to be removed later if not needed.
 */
extension CVPixelBufferUtils {
    // TODO: Check if any of the methods can be sped up using GPU
    // TODO: Check if the forced unwrapping used all over the functions is safe in the given context
    static func cropCenterOfPixelBuffer(_ pixelBuffer: CVPixelBuffer, cropSize: CGSize) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let cropX = (Float(width) - Float(cropSize.width)) / 2
        let cropY = (Float(height) - Float(cropSize.height)) / 2
        var croppedPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(cropSize.width), Int(cropSize.height), CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &croppedPixelBuffer)
        guard status == kCVReturnSuccess, let outputBuffer = croppedPixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(outputBuffer, [])

        let inputBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
        let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer)!

        let inputBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)

        let cropXOffset = Int(cropX) * 4
        let cropYOffset = Int(cropY) * inputBytesPerRow
        for y in 0..<Int(cropSize.height) {
            let inputRow = inputBaseAddress.advanced(by: cropYOffset + cropXOffset + y * inputBytesPerRow)
            let outputRow = outputBaseAddress.advanced(by: y * outputBytesPerRow)
            memcpy(outputRow, inputRow, Int(cropSize.width) * 4)
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(outputBuffer, [])

        return outputBuffer
    }

    static func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        var resizedPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &resizedPixelBuffer)
        guard status == kCVReturnSuccess, let outputBuffer = resizedPixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(outputBuffer, [])

        let inputBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
        let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer)!

        var inBuffer = vImage_Buffer(data: inputBaseAddress,
                                     height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)),
                                     width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)),
                                     rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer))

        var outBuffer = vImage_Buffer(data: outputBaseAddress,
                                      height: vImagePixelCount(height),
                                      width: vImagePixelCount(width),
                                      rowBytes: CVPixelBufferGetBytesPerRow(outputBuffer))

        let scaleError = vImageScale_ARGB8888(&inBuffer, &outBuffer, nil, vImage_Flags(0))
        guard scaleError == kvImageNoError else { return nil }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(outputBuffer, [])

        return outputBuffer
    }

    static func resizeAndCropPixelBuffer(_ pixelBuffer: CVPixelBuffer, targetSize: CGSize, cropSize: CGSize) -> CVPixelBuffer? {
        guard let resizedPixelBuffer = resizePixelBuffer(pixelBuffer, width: Int(targetSize.width), height: Int(targetSize.height)) else {
            return nil
        }
        return cropCenterOfPixelBuffer(resizedPixelBuffer, cropSize: cropSize)
    }
    
    /// Temporary function to get the average value of a pixel in a depth image
    /// Only used for debugging purposes
    static func averagePixelBufferValue(in pixelBuffer: CVPixelBuffer) -> Float32? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard pixelFormat == kCVPixelFormatType_DepthFloat32 else {
            print("Unsupported pixel format: \(pixelFormat)")
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let totalPixels = width * height
        var sum: Float32 = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = y * bytesPerRow / MemoryLayout<Float32>.size + x
                sum += floatBuffer[index]
            }
        }
        
        return sum / Float32(totalPixels)
    }
}

extension CVPixelBuffer {
    /**
        Returns a string representation of the pixel format type of the pixel buffer.
     */
    func pixelFormatName() -> String {
        let p = CVPixelBufferGetPixelFormatType(self)
        switch p {
        case kCVPixelFormatType_1Monochrome:                   return "kCVPixelFormatType_1Monochrome"
        case kCVPixelFormatType_2Indexed:                      return "kCVPixelFormatType_2Indexed"
        case kCVPixelFormatType_4Indexed:                      return "kCVPixelFormatType_4Indexed"
        case kCVPixelFormatType_8Indexed:                      return "kCVPixelFormatType_8Indexed"
        case kCVPixelFormatType_1IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_1IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_2IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_2IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_4IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_4IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_8IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_8IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_16BE555:                       return "kCVPixelFormatType_16BE555"
        case kCVPixelFormatType_16LE555:                       return "kCVPixelFormatType_16LE555"
        case kCVPixelFormatType_16LE5551:                      return "kCVPixelFormatType_16LE5551"
        case kCVPixelFormatType_16BE565:                       return "kCVPixelFormatType_16BE565"
        case kCVPixelFormatType_16LE565:                       return "kCVPixelFormatType_16LE565"
        case kCVPixelFormatType_24RGB:                         return "kCVPixelFormatType_24RGB"
        case kCVPixelFormatType_24BGR:                         return "kCVPixelFormatType_24BGR"
        case kCVPixelFormatType_32ARGB:                        return "kCVPixelFormatType_32ARGB"
        case kCVPixelFormatType_32BGRA:                        return "kCVPixelFormatType_32BGRA"
        case kCVPixelFormatType_32ABGR:                        return "kCVPixelFormatType_32ABGR"
        case kCVPixelFormatType_32RGBA:                        return "kCVPixelFormatType_32RGBA"
        case kCVPixelFormatType_64ARGB:                        return "kCVPixelFormatType_64ARGB"
        case kCVPixelFormatType_48RGB:                         return "kCVPixelFormatType_48RGB"
        case kCVPixelFormatType_32AlphaGray:                   return "kCVPixelFormatType_32AlphaGray"
        case kCVPixelFormatType_16Gray:                        return "kCVPixelFormatType_16Gray"
        case kCVPixelFormatType_30RGB:                         return "kCVPixelFormatType_30RGB"
        case kCVPixelFormatType_422YpCbCr8:                    return "kCVPixelFormatType_422YpCbCr8"
        case kCVPixelFormatType_4444YpCbCrA8:                  return "kCVPixelFormatType_4444YpCbCrA8"
        case kCVPixelFormatType_4444YpCbCrA8R:                 return "kCVPixelFormatType_4444YpCbCrA8R"
        case kCVPixelFormatType_4444AYpCbCr8:                  return "kCVPixelFormatType_4444AYpCbCr8"
        case kCVPixelFormatType_4444AYpCbCr16:                 return "kCVPixelFormatType_4444AYpCbCr16"
        case kCVPixelFormatType_444YpCbCr8:                    return "kCVPixelFormatType_444YpCbCr8"
        case kCVPixelFormatType_422YpCbCr16:                   return "kCVPixelFormatType_422YpCbCr16"
        case kCVPixelFormatType_422YpCbCr10:                   return "kCVPixelFormatType_422YpCbCr10"
        case kCVPixelFormatType_444YpCbCr10:                   return "kCVPixelFormatType_444YpCbCr10"
        case kCVPixelFormatType_420YpCbCr8Planar:              return "kCVPixelFormatType_420YpCbCr8Planar"
        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:     return "kCVPixelFormatType_420YpCbCr8PlanarFullRange"
        case kCVPixelFormatType_422YpCbCr_4A_8BiPlanar:        return "kCVPixelFormatType_422YpCbCr_4A_8BiPlanar"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:  return "kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange"
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:   return "kCVPixelFormatType_420YpCbCr8BiPlanarFullRange"
        case kCVPixelFormatType_422YpCbCr8_yuvs:               return "kCVPixelFormatType_422YpCbCr8_yuvs"
        case kCVPixelFormatType_422YpCbCr8FullRange:           return "kCVPixelFormatType_422YpCbCr8FullRange"
        case kCVPixelFormatType_OneComponent8:                 return "kCVPixelFormatType_OneComponent8"
        case kCVPixelFormatType_TwoComponent8:                 return "kCVPixelFormatType_TwoComponent8"
        case kCVPixelFormatType_30RGBLEPackedWideGamut:        return "kCVPixelFormatType_30RGBLEPackedWideGamut"
        case kCVPixelFormatType_OneComponent16:                return "kCVPixelFormatType_OneComponent16"
        case kCVPixelFormatType_OneComponent16Half:            return "kCVPixelFormatType_OneComponent16Half"
        case kCVPixelFormatType_OneComponent32Float:           return "kCVPixelFormatType_OneComponent32Float"
        case kCVPixelFormatType_TwoComponent16:                return "kCVPixelFormatType_TwoComponent16"
        case kCVPixelFormatType_TwoComponent16Half:            return "kCVPixelFormatType_TwoComponent16Half"
        case kCVPixelFormatType_TwoComponent32Float:           return "kCVPixelFormatType_TwoComponent32Float"
        case kCVPixelFormatType_64RGBAHalf:                    return "kCVPixelFormatType_64RGBAHalf"
        case kCVPixelFormatType_128RGBAFloat:                  return "kCVPixelFormatType_128RGBAFloat"
        case kCVPixelFormatType_14Bayer_GRBG:                  return "kCVPixelFormatType_14Bayer_GRBG"
        case kCVPixelFormatType_14Bayer_RGGB:                  return "kCVPixelFormatType_14Bayer_RGGB"
        case kCVPixelFormatType_14Bayer_BGGR:                  return "kCVPixelFormatType_14Bayer_BGGR"
        case kCVPixelFormatType_14Bayer_GBRG:                  return "kCVPixelFormatType_14Bayer_GBRG"
        case kCVPixelFormatType_DepthFloat16:                  return "kCVPixelFormatType_DepthFloat16"
        case kCVPixelFormatType_DepthFloat32:                  return "kCVPixelFormatType_DepthFloat32"
        default: return "UNKNOWN"
        }
    }
    
    /**
        Returns the corresponding (recommended) Metal pixel format for the pixel buffer's format type.
     */
    func metalPixelFormat(plane: Int = 0) -> MTLPixelFormat? {
        let p = CVPixelBufferGetPixelFormatType(self)
        switch p {
        case kCVPixelFormatType_OneComponent8, kCVPixelFormatType_TwoComponent8:
            return .r8Unorm
        case kCVPixelFormatType_OneComponent16, kCVPixelFormatType_TwoComponent16:
            return .r16Unorm
        case kCVPixelFormatType_OneComponent16Half, kCVPixelFormatType_TwoComponent16Half:
            return .r16Float
        case kCVPixelFormatType_OneComponent32Float, kCVPixelFormatType_TwoComponent32Float:
            return .r32Float
        case kCVPixelFormatType_16Gray:
            return .r16Unorm
        case kCVPixelFormatType_32BGRA:
            return .bgra8Unorm
        case kCVPixelFormatType_32RGBA:
            return .rgba8Unorm
        case kCVPixelFormatType_64RGBAHalf:
            return .rgba16Float
        case kCVPixelFormatType_128RGBAFloat:
            return .rgba32Float
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return plane == 0 ? .r8Unorm : .rg8Unorm
        case kCVPixelFormatType_420YpCbCr8Planar, kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            return .r8Unorm
        case kCVPixelFormatType_16LE565:
            return .b5g6r5Unorm
        default:
            // The rest either require conversion or are not mappable directly
            return nil
        }
    }
}
