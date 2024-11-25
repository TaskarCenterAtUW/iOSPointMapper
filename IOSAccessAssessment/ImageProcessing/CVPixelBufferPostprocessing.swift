import UIKit
import Accelerate


func computeCentroid(mask: CVPixelBuffer, depthMap: CVPixelBuffer, sidewalkLabel: UInt8 = 1) -> (Double, Double)? {
    // Ensure the dimensions of mask and depthMap are the same
    guard CVPixelBufferGetWidth(mask) == CVPixelBufferGetWidth(depthMap),
          CVPixelBufferGetHeight(mask) == CVPixelBufferGetHeight(depthMap) else {
        print("Mask and Depth Map dimensions do not match.")
        return nil
    }

    let width = CVPixelBufferGetWidth(mask)
    let height = CVPixelBufferGetHeight(mask)

    CVPixelBufferLockBaseAddress(mask, .readOnly)
    CVPixelBufferLockBaseAddress(depthMap, .readOnly)

    defer {
        CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
    }

    guard let maskBaseAddress = CVPixelBufferGetBaseAddress(mask),
          let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
        print("Failed to get base address of mask or depth map.")
        return nil
    }

    var xIndices = [Int]()
    var yIndices = [Int]()

    for y in 0..<height {
        for x in 0..<width {
            let maskPixelIndex = y * CVPixelBufferGetBytesPerRow(mask) + x
            let maskValue = maskBaseAddress.assumingMemoryBound(to: UInt8.self)[maskPixelIndex]
            if maskValue == sidewalkLabel {
                xIndices.append(x)
                yIndices.append(y)
            }
        }
    }

    if xIndices.isEmpty || yIndices.isEmpty {
        print("No sidewalk pixels found.")
        return nil
    }

    let xMedian = Double(xIndices.sorted()[xIndices.count / 2])
    let yMedian = Double(yIndices.sorted()[yIndices.count / 2])

    return (xMedian, yMedian)
}

func computeSidewalkWidth(mask: CVPixelBuffer, depthMap: CVPixelBuffer, centroid: (Double, Double)) -> Double? {
    let centroidX = Int(centroid.0)
    let centroidY = Int(centroid.1)

    guard CVPixelBufferGetWidth(mask) == CVPixelBufferGetWidth(depthMap),
          CVPixelBufferGetHeight(mask) == CVPixelBufferGetHeight(depthMap) else {
        print("Mask and Depth Map dimensions do not match.")
        return nil
    }

    let width = CVPixelBufferGetWidth(mask)
    CVPixelBufferLockBaseAddress(mask, .readOnly)
    CVPixelBufferLockBaseAddress(depthMap, .readOnly)

    defer {
        CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
    }

    guard let maskBaseAddress = CVPixelBufferGetBaseAddress(mask),
          let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
        print("Failed to get base address of mask or depth map.")
        return nil
    }

    let rowOffset = centroidY * CVPixelBufferGetBytesPerRow(mask)
    var sidewalkIndices = [Int]()

    for x in 0..<width {
        let maskValue = maskBaseAddress.assumingMemoryBound(to: UInt8.self)[rowOffset + x]
        if maskValue > 0 {
            sidewalkIndices.append(x)
        }
    }

    if sidewalkIndices.count < 2 {
        print("Cannot find sidewalk edges at the centroid location.")
        return nil
    }

    let leftPixel = sidewalkIndices.first!
    let rightPixel = sidewalkIndices.last!

    let sideDepth = depthBaseAddress.assumingMemoryBound(to: Double.self)[centroidY * width + centroidX]
    let leftDepth = depthBaseAddress.assumingMemoryBound(to: Double.self)[centroidY * width + leftPixel]
    let rightDepth = depthBaseAddress.assumingMemoryBound(to: Double.self)[centroidY * width + rightPixel]

    let leftEstimate = sqrt(pow(leftDepth, 2) - pow(sideDepth, 2))
    let rightEstimate = sqrt(pow(rightDepth, 2) - pow(sideDepth, 2))

    return (leftEstimate + rightEstimate) / 2
}

func erosion(pixelBuffer: CVPixelBuffer, kernel: [[Int]]) -> CVPixelBuffer? {
    let kernelHeight = kernel.count
    let kernelWidth = kernel[0].count
    let padH = kernelHeight / 2
    let padW = kernelWidth / 2

    // Lock the base address of the input pixel buffer
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        print("Unable to access base address of the pixel buffer")
        return nil
    }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

    // Create a new pixel buffer for the eroded image
    var erodedPixelBuffer: CVPixelBuffer?
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        pixelFormat,
        nil,
        &erodedPixelBuffer
    )
    
    guard let erodedBuffer = erodedPixelBuffer else {
        print("Unable to create output pixel buffer")
        return nil
    }

    CVPixelBufferLockBaseAddress(erodedBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(erodedBuffer, []) }
    
    guard let erodedBaseAddress = CVPixelBufferGetBaseAddress(erodedBuffer) else {
        print("Unable to access base address of the output pixel buffer")
        return nil
    }
    
    // Pointers to image data
    let inputData = baseAddress.assumingMemoryBound(to: UInt8.self)
    let outputData = erodedBaseAddress.assumingMemoryBound(to: UInt8.self)

    for y in 0..<height {
        for x in 0..<width {
            var match = true

            for ky in 0..<kernelHeight {
                for kx in 0..<kernelWidth {
                    let offsetY = y + ky - padH
                    let offsetX = x + kx - padW

                    // Check boundary conditions
                    if offsetY >= 0, offsetY < height, offsetX >= 0, offsetX < width {
                        let pixelOffset = offsetY * bytesPerRow + offsetX
                        let kernelValue = kernel[ky][kx]
                        if kernelValue == 1, inputData[pixelOffset] == 0 {
                            match = false
                        }
                    } else if kernel[ky][kx] == 1 {
                        match = false
                    }
                }
            }

            // Set the eroded pixel value
            let outputOffset = y * bytesPerRow + x
            outputData[outputOffset] = match ? 255 : 0
        }
    }

    return erodedBuffer
}


func dilation(pixelBuffer: CVPixelBuffer, kernel: [[Int]]) -> CVPixelBuffer? {
    let kernelHeight = kernel.count
    let kernelWidth = kernel[0].count
    let padH = kernelHeight / 2
    let padW = kernelWidth / 2

    // Lock the base address of the input pixel buffer
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        print("Unable to access base address of the pixel buffer")
        return nil
    }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

    // Create a new pixel buffer for the dilated image
    var dilatedPixelBuffer: CVPixelBuffer?
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        pixelFormat,
        nil,
        &dilatedPixelBuffer
    )
    
    guard let dilatedBuffer = dilatedPixelBuffer else {
        print("Unable to create output pixel buffer")
        return nil
    }

    CVPixelBufferLockBaseAddress(dilatedBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(dilatedBuffer, []) }
    
    guard let dilatedBaseAddress = CVPixelBufferGetBaseAddress(dilatedBuffer) else {
        print("Unable to access base address of the output pixel buffer")
        return nil
    }
    
    // Pointers to image data
    let inputData = baseAddress.assumingMemoryBound(to: UInt8.self)
    let outputData = dilatedBaseAddress.assumingMemoryBound(to: UInt8.self)

    for y in 0..<height {
        for x in 0..<width {
            var match = false

            for ky in 0..<kernelHeight {
                for kx in 0..<kernelWidth {
                    let offsetY = y + ky - padH
                    let offsetX = x + kx - padW

                    // Check boundary conditions
                    if offsetY >= 0, offsetY < height, offsetX >= 0, offsetX < width {
                        let pixelOffset = offsetY * bytesPerRow + offsetX
                        let kernelValue = kernel[ky][kx]
                        if kernelValue == 1, inputData[pixelOffset] == 255 {
                            match = true
                        }
                    }
                }
            }

            // Set the dilated pixel value
            let outputOffset = y * bytesPerRow + x
            outputData[outputOffset] = match ? 255 : 0
        }
    }

    return dilatedBuffer
}


func opening(pixelBuffer: CVPixelBuffer, kernel: [[Int]]) -> CVPixelBuffer? {
    // Perform erosion first
    guard let erodedPixelBuffer = erosion(pixelBuffer: pixelBuffer, kernel: kernel) else {
        print("Error during erosion step")
        return nil
    }
    
    // Perform dilation on the result of erosion
    guard let openedPixelBuffer = dilation(pixelBuffer: erodedPixelBuffer, kernel: kernel) else {
        print("Error during dilation step")
        return nil
    }
    
    return openedPixelBuffer
}


func closing(pixelBuffer: CVPixelBuffer, kernel: [[Int]]) -> CVPixelBuffer? {
    // Perform dilation first
    guard let dilatedPixelBuffer = dilation(pixelBuffer: pixelBuffer, kernel: kernel) else {
        print("Error during dilation step")
        return nil
    }
    
    // Perform erosion on the result of dilation
    guard let closedPixelBuffer = erosion(pixelBuffer: dilatedPixelBuffer, kernel: kernel) else {
        print("Error during erosion step")
        return nil
    }
    
    return closedPixelBuffer
}


func cleanMask(pixelBuffer: CVPixelBuffer, kernelSize: Int = 5) -> CVPixelBuffer? {
    // Create a square structuring element (kernel) of given size
    let kernel = Array(repeating: Array(repeating: 1, count: kernelSize), count: kernelSize)
    
    // Ensure the mask is binary (this assumes the input is already binary, otherwise preprocessing is needed)
    // Apply opening
    guard let openedPixelBuffer = opening(pixelBuffer: pixelBuffer, kernel: kernel) else {
        print("Error during opening step")
        return nil
    }
    
    // Apply closing
    guard let cleanedPixelBuffer = closing(pixelBuffer: openedPixelBuffer, kernel: kernel) else {
        print("Error during closing step")
        return nil
    }
    
    return cleanedPixelBuffer
}


func depthCleanMask(mask: CVPixelBuffer, depthMap: CVPixelBuffer, sidewalkLabel: UInt8 = 1, depthThreshold: Float = 0.25) -> CVPixelBuffer? {
    // Ensure the mask and depth map have the same dimensions
    let width = CVPixelBufferGetWidth(mask)
    let height = CVPixelBufferGetHeight(mask)
    let maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask)
    let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

    guard width == CVPixelBufferGetWidth(depthMap),
          height == CVPixelBufferGetHeight(depthMap) else {
        print("Mask and depth map dimensions do not match")
        return nil
    }

    // Lock base addresses for both buffers
    CVPixelBufferLockBaseAddress(mask, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
    CVPixelBufferLockBaseAddress(depthMap, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
    
    guard let maskBaseAddress = CVPixelBufferGetBaseAddress(mask),
          let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
        print("Unable to access base addresses of the pixel buffers")
        return nil
    }

    let maskData = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
    let depthData = depthBaseAddress.assumingMemoryBound(to: Float.self)

    // Create a cleaned mask buffer
    var cleanedMask: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, nil, &cleanedMask)
    
    guard let outputMask = cleanedMask else {
        print("Unable to create output pixel buffer")
        return nil
    }

    CVPixelBufferLockBaseAddress(outputMask, [])
    defer { CVPixelBufferUnlockBaseAddress(outputMask, []) }

    guard let cleanedMaskBaseAddress = CVPixelBufferGetBaseAddress(outputMask) else {
        print("Unable to access base address of the cleaned mask buffer")
        return nil
    }

    let cleanedMaskData = cleanedMaskBaseAddress.assumingMemoryBound(to: UInt8.self)

    // Calculate the mean depth for the sidewalk label
    var totalDepth: Float = 0
    var count: Int = 0

    for y in 0..<height {
        for x in 0..<width {
            let maskOffset = y * maskBytesPerRow + x
            let depthOffset = y * depthBytesPerRow / MemoryLayout<Float>.size + x

            if maskData[maskOffset] == sidewalkLabel {
                totalDepth += depthData[depthOffset]
                count += 1
            }
        }
    }

    guard count > 0 else {
        print("No sidewalk pixels found in the mask")
        return nil
    }

    let meanDepth = totalDepth / Float(count)

    // Clean the mask based on depth threshold
    for y in 0..<height {
        for x in 0..<width {
            let maskOffset = y * maskBytesPerRow + x
            let depthOffset = y * depthBytesPerRow / MemoryLayout<Float>.size + x

            if maskData[maskOffset] == sidewalkLabel {
                let depthValue = depthData[depthOffset]
                if abs(depthValue - meanDepth) > depthThreshold {
                    cleanedMaskData[maskOffset] = 0 // Remove the pixel from the mask
                } else {
                    cleanedMaskData[maskOffset] = sidewalkLabel
                }
            } else {
                cleanedMaskData[maskOffset] = maskData[maskOffset]
            }
        }
    }

    return outputMask
}
