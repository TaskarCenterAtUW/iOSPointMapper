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

func createBlackDepthPixelBuffer(targetSize: CGSize) -> CVPixelBuffer? {
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

func printDepthPixel(from depthBuffer: CVPixelBuffer, atX x: Int, atY y: Int) {
    // Lock the base address of the pixel buffer before accessing the data
    CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)

    // Get the width and height of the depth buffer
    let width = CVPixelBufferGetWidth(depthBuffer)
    let height = CVPixelBufferGetHeight(depthBuffer)

    // Ensure that the coordinates are within bounds
    guard x < width, y < height else {
        print("Pixel coordinates are out of bounds")
        return
    }
    
    if let baseAddress = CVPixelBufferGetBaseAddress(depthBuffer) {
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
        
        let pixelOffset = Int(y) * bytesPerRow / MemoryLayout<Float>.size + Int(x)
        let depthValue = floatBuffer[pixelOffset]
        
        // Print the depth value (in meters)
        print("Depth value at (\(x), \(y)) is \(depthValue) meters")
    }

    // Unlock the base address
    CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)
}

func pixelBufferToData(_ pixelBuffer: CVPixelBuffer) -> Data {
    CVPixelBufferLockBaseAddress(pixelBuffer, [.readOnly])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, [.readOnly]) }
    
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    // Get the width and height of the pixel buffer
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
//    print("pixel format type: \(pixelFormat)")
//    print("pixel buffer plane count: \(CVPixelBufferGetPlaneCount(pixelBuffer))")
    
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
    // Calculate the total size of the data (width * height * size of each Float32)
    let totalSize = width * height * MemoryLayout<Float32>.size
    
    // Create a Data object from the buffer's base address
    let data = Data(bytes: baseAddress, count: totalSize)
    
    return data
}

func savePixelBufferAsBinary(_ pixelBuffer: CVPixelBuffer, fileName: String) -> URL? {
    // Create a Swift Data object to hold the raw depth values
    let data = pixelBufferToData(pixelBuffer)
    
    // Save the Data object to a file in the documents directory
    let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
    do {
        try data.write(to: fileURL)
        print("CVPixelBuffer data saved to \(fileURL.path)")
        return fileURL
    } catch {
        print("Error saving CVPixelBuffer data: \(error)")
        return nil
    }
}
