//
//  PlaneWidthProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/2/26.
//

import ARKit
import RealityKit
import MetalKit
import Accelerate
import simd

enum PlaneAttributeProcessorError: Error, LocalizedError {
    case metalInitializationFailed
    case metalPipelineCreationError
    case metalPipelineBlitEncoderError
    case endpointsComputationFailed
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        case .metalPipelineCreationError:
            return "Failed to create Metal compute pipeline."
        case .metalPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Plane Width Processor."
        case .endpointsComputationFailed:
            return "Failed to compute endpoints from projected points."
        }
    }
}

struct ProjectedPointBin: Sendable {
    let binValueCount: Int
    let binValues: [Float]
    let sRange: (Float, Float)
}

struct ProjectedPointBins: Sendable {
    let binCount: Int
    let bins: [ProjectedPointBin]
}

struct BinWidth: Sendable {
    let width: Float
    let count: Int
}

struct PlaneAttributeProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw WorldPointsProcessorError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "binProjectedPoints"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw WorldPointsProcessorError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }
    
    /**
        Bin projected points along the 's' axis.
     
        - Parameters:
            - projectedPoints: An array of ProjectedPoint to be binned.
            - binSize: The size of each bin along the 's' axis. Default is 0.25.
     
        - Returns: A ProjectedPointBinValues containing the binned values.
     */
    func binProjectedPoints(
        projectedPoints: [ProjectedPoint],
        binSize: Float = 0.25
    ) throws -> ProjectedPointBins {
        var projectedPointCount = projectedPoints.count
        guard let firstProjectedPoint = projectedPoints.first else {
            return ProjectedPointBins(binCount: 0, bins: [])
        }
        var sMin: Float = firstProjectedPoint.s
        var sMax: Float = firstProjectedPoint.s
        for projectedPoint in projectedPoints {
            if projectedPoint.s < sMin {
                sMin = projectedPoint.s
            }
            if projectedPoint.s > sMax {
                sMax = projectedPoint.s
            }
        }
        let binCount = Int(ceil((sMax - sMin) / binSize))
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw PlaneAttributeProcessorError.metalPipelineCreationError
        }
        
        /// Set up the projected points buffer
        let projectedPointsBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<ProjectedPoint>.stride * projectedPointCount,
            options: .storageModeShared
        )
        let projectedPointsBufferPtr = projectedPointsBuffer.contents()
        projectedPoints.withUnsafeBytes { srcPtr in
            guard let baseAddress = srcPtr.baseAddress else { return }
            projectedPointsBufferPtr.copyMemory(
                from: baseAddress,
                byteCount: MemoryLayout<ProjectedPoint>.stride * projectedPointCount
            )
        }
        /// TODO: Find a more optimal maxValuesPerBin.
        var params = ProjectedPointBinningParams(
            sMin: sMin, sMax: sMax, sBinSize: binSize,
            binCount: UInt32(binCount), maxValuesPerBin: UInt32(projectedPointCount)
        )
        /// Set up buffers for output
        let binCountsBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<UInt32>.stride * binCount,
            options: .storageModeShared
        )
        let binValuesBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<Float>.stride * binCount * projectedPointCount,
            options: .storageModeShared
        )
        
        let threadGroupSizeWidth = min(self.pipeline.maxTotalThreadsPerThreadgroup, 256)
        
        /**
         Initialize point count to zero.
         */
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw PlaneAttributeProcessorError.metalPipelineBlitEncoderError
        }
        blit.fill(buffer: binCountsBuffer, range: 0..<(MemoryLayout<UInt32>.stride * binCount), value: 0)
        blit.endEncoding()
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw PlaneAttributeProcessorError.metalPipelineCreationError
        }
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setBuffer(projectedPointsBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&projectedPointCount, length: MemoryLayout<UInt32>.size, index: 1)
        commandEncoder.setBytes(&params, length: MemoryLayout<ProjectedPointBinningParams>.size, index: 2)
        commandEncoder.setBuffer(binCountsBuffer, offset: 0, index: 3)
        commandEncoder.setBuffer(binValuesBuffer, offset: 0, index: 4)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (projectedPointCount + threadGroupSize.width - 1) / threadGroupSize.width,
                                    height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let binCountsPtr = binCountsBuffer.contents().bindMemory(to: UInt32.self, capacity: binCount)
        let binValuesPtr = binValuesBuffer.contents().bindMemory(to: Float.self, capacity: binCount * projectedPointCount)
        var bins: [ProjectedPointBin] = []
        for binIndex in 0..<binCount {
            let count = Int(binCountsPtr[binIndex])
            var valuesForBin: [Float] = []
            for valueIndex in 0..<count {
                let value = binValuesPtr[binIndex * projectedPointCount + valueIndex]
                valuesForBin.append(value)
            }
            let sRangeMin = sMin + Float(binIndex) * binSize
            let sRangeMax = sRangeMin + binSize
            bins.append(ProjectedPointBin(binValueCount: count, binValues: valuesForBin, sRange: (sRangeMin, sRangeMax)))
        }
        return ProjectedPointBins(
            binCount: binCount, bins: bins
        )
    }
    
    /**
        Compute the width of the plane by analyzing the binned projected point values.
     
        - Parameters:
            - projectedPointBinValues: The binned projected point values.
            - minCount: Minimum number of points required in a bin to consider it for width computation. Default is 100.
            - trimLow: The lower percentile to trim when computing width. Default is 0.05.
            - trimHigh: The upper percentile to trim when computing width. Default is 0.
     
        - Returns: An array of BinWidth representing the computed widths for each bin.
     */
    func computeWidthByBin(
        projectedPointBins: ProjectedPointBins,
        minCount: Int = 100,
        trimLow: Float = 0.05, trimHigh: Float = 0.95
    ) -> [BinWidth] {
        var binWidths: [BinWidth] = []
        let binCount = projectedPointBins.binCount
        for binIndex in 0..<binCount {
            let bin = projectedPointBins.bins[binIndex]
            let count = bin.binValueCount
            guard count >= minCount else {
                continue
            }
            let values = bin.binValues
            /// Can replace with Accelerate framework for better performance if arrays are large
            let sortedValues = values.sorted()
            
            let trimLowIndex = Int(Float(count) * trimLow)
            let trimHighIndex = Int(Float(count) * trimHigh)
            
            let width = abs(sortedValues[trimHighIndex] - sortedValues[trimLowIndex])
            
            binWidths.append(BinWidth(width: width, count: count))
        }
        return binWidths
    }
    
    /**
     Get the endpoints of the sidewalk along the 's' axis by analyzing the projected points.
     */
    func getEndpointsFromBins(
        projectedPointBins: ProjectedPointBins,
        trimLow: Float = 0.05, trimHigh: Float = 0.95
    ) throws -> (ProjectedPoint, ProjectedPoint) {
        /// Get the first and the last bin that has enough points to be considered valid
        let validBins = projectedPointBins.bins.filter { $0.binValueCount > 0 }
        guard let firstValidBin = validBins.first, let lastValidBin = validBins.last else {
            throw PlaneAttributeProcessorError.endpointsComputationFailed
        }
        let firstBinValues = firstValidBin.binValues
        let lastBinValues = lastValidBin.binValues
        let firstBinSortedValues = firstBinValues.sorted()
        let lastBinSortedValues = lastBinValues.sorted()
        let firstBinTrimLowIndex = Int(Float(firstBinValues.count) * trimLow)
        let firstBinTrimHighIndex = Int(Float(firstBinValues.count) * trimHigh)
        let lastBinTrimLowIndex = Int(Float(lastBinValues.count) * trimLow)
        let lastBinTrimHighIndex = Int(Float(lastBinValues.count) * trimHigh)
        let firstEndpointS = (firstValidBin.sRange.0 + firstValidBin.sRange.1) / 2
        let lastEndpointS = (lastValidBin.sRange.0 + lastValidBin.sRange.1) / 2
        
        let firstEndpoint = ProjectedPoint(s: firstEndpointS, t: (firstBinSortedValues[firstBinTrimLowIndex] + firstBinSortedValues[firstBinTrimHighIndex]) / 2)
        let lastEndpoint = ProjectedPoint(s: lastEndpointS, t: (lastBinSortedValues[lastBinTrimLowIndex] + lastBinSortedValues[lastBinTrimHighIndex]) / 2)
        return (firstEndpoint, lastEndpoint)
    }
}
