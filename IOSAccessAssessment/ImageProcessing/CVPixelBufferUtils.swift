//
//  CVPixelBufferUtils.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/27/24.
//

import UIKit
import Accelerate

// TODO: Check if any of the methods can be sped up using GPU
// TODO: Check if the forced unwrapping used all over the functions is safe in the given context
func cropCenterOfPixelBuffer(_ pixelBuffer: CVPixelBuffer, cropSize: CGSize) -> CVPixelBuffer? {
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

func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
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

func resizeAndCropPixelBuffer(_ pixelBuffer: CVPixelBuffer, targetSize: CGSize, cropSize: CGSize) -> CVPixelBuffer? {
    guard let resizedPixelBuffer = resizePixelBuffer(pixelBuffer, width: Int(targetSize.width), height: Int(targetSize.height)) else {
        return nil
    }
    return cropCenterOfPixelBuffer(resizedPixelBuffer, cropSize: cropSize)
}

func createBlankDepthPixelBuffer(targetSize: CGSize) -> CVPixelBuffer? {
    let width = Int(targetSize.width)
    let height = Int(targetSize.height)
    
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_DepthFloat32, nil, &pixelBuffer)
    
    guard status == kCVReturnSuccess, let blankPixelBuffer = pixelBuffer else { return nil }
    
    CVPixelBufferLockBaseAddress(blankPixelBuffer, [])
    let blankBaseAddress = CVPixelBufferGetBaseAddress(blankPixelBuffer)!
    let blankBufferPointer = blankBaseAddress.bindMemory(to: Float.self, capacity: width * height)
    vDSP_vclr(blankBufferPointer, 1, vDSP_Length(width * height))
    CVPixelBufferUnlockBaseAddress(blankPixelBuffer, [])
    
    return blankPixelBuffer
}

func extractUniqueGrayscaleValuesAccelerate(from pixelBuffer: CVPixelBuffer) -> (Set<UInt8>, [Int]) {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return (Set<UInt8>(), [])
    }
    
    var buffer = vImage_Buffer(data: baseAddress,
                                 height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)),
                                 width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)),
                                 rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer))
    var histogram = [vImagePixelCount](repeating: 0, count: 256)
    let error = vImageHistogramCalculation_Planar8(&buffer, &histogram, vImage_Flags(kvImageNoFlags))
    
    var uniqueValues = Set<UInt8>()
    for i in 0..<histogram.count {
        if histogram[i] > 0 {
            uniqueValues.insert(UInt8(i))
        }
    }
    
    let valueToIndex = Dictionary(uniqueKeysWithValues: Constants.ClassConstants.grayscaleValues.enumerated().map { ($0.element, $0.offset) })
    
    // MARK: sorting may not be necessary for our use case
    let selectedIndices = uniqueValues.map { UInt8($0) }
        .map {Float($0) / 255.0 }
        .compactMap { valueToIndex[$0]}
        .sorted()
        
    return (uniqueValues, selectedIndices)
}
