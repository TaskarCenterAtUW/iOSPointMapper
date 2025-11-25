//
//  SegmentationMeshRecord.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/6/25.
//
import ARKit
import RealityKit
import MetalKit

enum SegmentationMeshRecordError: Error, LocalizedError {
    case isProcessingTrue
    case emptySegmentation
    case segmentationTextureError
    case segmentationBufferFormatNotSupported
    case accessibilityFeatureClassificationParamsError
    case metalInitializationError
    case metalPipelineCreationError
    case meshPipelineBlitEncoderError
    case unexpectedError
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The Segmentation Mesh Pipeline is already processing a request."
        case .emptySegmentation:
            return "The Segmentation Image does not contain any valid segmentation data."
        case .segmentationTextureError:
            return "Failed to create Metal texture from the segmentation image."
        case .segmentationBufferFormatNotSupported:
            return "The pixel format of the segmentation image is not supported for Metal texture creation."
        case .accessibilityFeatureClassificationParamsError:
            return "Failed to set up accessibility feature classification parameters for the Segmentation Mesh Creation."
        case .metalInitializationError:
            return "Failed to initialize Metal resources for the Segmentation Mesh Creation."
        case .metalPipelineCreationError:
            return "Failed to create Metal pipeline state for the Segmentation Mesh Creation."
        case .meshPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Segmentation Mesh Creation."
        case .unexpectedError:
            return "An unexpected error occurred in the Segmentation Mesh Pipeline."
        }
    }
}

@MainActor
final class SegmentationMeshRecord {
    let entity: ModelEntity
    let name: String
    let color: UIColor
    let opacity: Float
    
    var mesh: LowLevelMesh
    var vertexCount: Int
    var indexCount: Int
    
    let accessibilityFeatureClass: AccessibilityFeatureClass
    let accessibilityFeatureMeshClassificationParams: AccessibilityFeatureMeshClassificationParams
    
    let context: MeshGPUContext
    let pipelineState: MTLComputePipelineState
    
    init(
        _ context: MeshGPUContext,
        meshGPUSnapshot: MeshGPUSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws {
        self.context = context
        guard let kernelFunction = context.device.makeDefaultLibrary()?.makeFunction(name: "processMesh") else {
            throw SegmentationMeshRecordError.metalInitializationError
        }
        self.pipelineState = try context.device.makeComputePipelineState(function: kernelFunction)
        
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.name = "Mesh_\(accessibilityFeatureClass.name)"
        self.color = UIColor(ciColor: accessibilityFeatureClass.color)
        self.opacity = 0.7
        
        self.accessibilityFeatureMeshClassificationParams = try SegmentationMeshRecord.getAccessibilityFeatureMeshClassificationParams(
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        
        let descriptor = SegmentationMeshRecord.createDescriptor(meshGPUSnapshot: meshGPUSnapshot)
        self.mesh = try LowLevelMesh(descriptor: descriptor)
        self.vertexCount = 0
        self.indexCount = 0
        self.entity = try SegmentationMeshRecord.generateEntity(
            mesh: self.mesh, color: color, opacity: opacity, name: name
        )
        try self.replace(
            meshGPUSnapshot: meshGPUSnapshot,
            segmentationImage: segmentationImage, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
    }
    
    func replace(
        meshGPUSnapshot: MeshGPUSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws {
        try self.update(
            meshGPUSnapshot: meshGPUSnapshot,
            segmentationImage: segmentationImage,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
    }
    
    func update(
        meshGPUSnapshot: MeshGPUSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws {
        // TODO: The assumption that segmentationImage.pixelBuffer is available may not always hold true.
        // Need to implement a more robust way to create MTLTexture from CIImage that does not depend on pixelBuffer.
        guard let segmentationPixelBuffer = segmentationImage.pixelBuffer else {
            throw SegmentationMeshRecordError.emptySegmentation
        }
        CVPixelBufferLockBaseAddress(segmentationPixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(segmentationPixelBuffer, .readOnly)
        }
        
        let meshGPUAnchors = meshGPUSnapshot.anchors
        
        let totalFaceCount = meshGPUAnchors.reduce(0) { $0 + $1.value.faceCount }
        let maxTriangles   = max(totalFaceCount, 1)     // avoid 0-sized buffers
        let maxVerts       = maxTriangles * 3
        let maxIndices     = maxTriangles * 3
        
        // Potential replacement of mesh if capacity exceeded
        var mesh = self.mesh
        // TODO: Optimize reallocation strategy to reduce overallocation
        if (mesh.descriptor.vertexCapacity < maxVerts) ||
            (mesh.descriptor.indexCapacity < maxIndices) {
            let meshName = self.name.replacingOccurrences(of: " ", with: "_")
            print("SegmentationMeshRecord '\(meshName)' capacity exceeded. Reallocating mesh.")
            let newDescriptor = SegmentationMeshRecord.createDescriptor(meshGPUSnapshot: meshGPUSnapshot)
            mesh = try LowLevelMesh(descriptor: newDescriptor)
            let resource = try MeshResource(from: mesh)
            self.entity.model?.mesh = resource
        }
        
        let outTriCount: MTLBuffer = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        // For debugging
        let debugSlots = Int(3) // MARK: Hard-coded
        let debugBytes = debugSlots * MemoryLayout<UInt32>.stride
        let debugCounter: MTLBuffer = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: debugBytes, options: .storageModeShared
        )
        
        let aabbMinU = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: 3 * MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        let aabbMaxU = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: 3 * MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        do {
            let minPtr = aabbMinU.contents().bindMemory(to: UInt32.self, capacity: 3)
            let maxPtr = aabbMaxU.contents().bindMemory(to: UInt32.self, capacity: 3)
            let fMax: Float = .greatestFiniteMagnitude
            let fMin: Float = -Float.greatestFiniteMagnitude
            let initMin = floatToOrderedUInt(fMax)
            let initMax = floatToOrderedUInt(fMin)
            minPtr[0] = initMin; minPtr[1] = initMin; minPtr[2] = initMin
            maxPtr[0] = initMax; maxPtr[1] = initMax; maxPtr[2] = initMax
        }
        
        // Set up additional parameters
        let viewMatrix = simd_inverse(cameraTransform)
        let imageSize = simd_uint2(UInt32(segmentationImage.extent.width), UInt32(segmentationImage.extent.height))
        // Set up the Metal command buffer
        guard let commandBuffer = self.context.commandQueue.makeCommandBuffer() else {
            throw SegmentationMeshRecordError.metalPipelineCreationError
        }
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw SegmentationMeshRecordError.meshPipelineBlitEncoderError
        }
        blit.fill(buffer: outTriCount, range: 0..<MemoryLayout<UInt32>.stride, value: 0)
        blit.fill(buffer: debugCounter, range: 0..<debugBytes, value: 0)
        blit.endEncoding()
        let threadGroupSizeWidth = min(self.pipelineState.maxTotalThreadsPerThreadgroup, 256)
        
        let outVertexBuf = mesh.replace(bufferIndex: 0, using: commandBuffer)
        let outIndexBuf = mesh.replaceIndices(using: commandBuffer)
        
//        let segmentationTexture = try getSegmentationMTLTexture(segmentationPixelBuffer: segmentationPixelBuffer)
        let segmentationTexture = try getSegmentationMTLTexture(segmentationImage: segmentationImage, commandBuffer: commandBuffer)
        
        var accessibilityFeatureMeshClassificationParams = self.accessibilityFeatureMeshClassificationParams
        
        for (_, anchor) in meshGPUSnapshot.anchors {
            guard anchor.faceCount > 0 else { continue }
            
            let hasClass: UInt32 = anchor.classificationBuffer != nil ? 1 : 0
            var params = MeshParams(
                faceCount: UInt32(anchor.faceCount), totalCount: UInt32(totalFaceCount),
                indicesPerFace: 3, hasClass: hasClass,
                anchorTransform: anchor.anchorTransform, cameraTransform: cameraTransform,
                viewMatrix: viewMatrix, intrinsics: cameraIntrinsics, imageSize: imageSize
            )
            guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw SegmentationMeshRecordError.metalPipelineCreationError
            }
            commandEncoder.setComputePipelineState(self.pipelineState)
            // Main inputs
            commandEncoder.setBuffer(anchor.vertexBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(anchor.indexBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(anchor.classificationBuffer ?? nil, offset: 0, index: 2)
            commandEncoder.setBytes(&params, length: MemoryLayout<MeshParams>.stride, index: 3)
            commandEncoder.setBytes(&accessibilityFeatureMeshClassificationParams,
                                    length: MemoryLayout<AccessibilityFeatureMeshClassificationParams>.stride, index: 4)
            commandEncoder.setTexture(segmentationTexture, index: 0)
            // Main outputs
            commandEncoder.setBuffer(outVertexBuf, offset: 0, index: 5)
            commandEncoder.setBuffer(outIndexBuf,  offset: 0, index: 6)
            commandEncoder.setBuffer(outTriCount,  offset: 0, index: 7)
            
            commandEncoder.setBuffer(aabbMinU, offset: 0, index: 8)
            commandEncoder.setBuffer(aabbMaxU, offset: 0, index: 9)
            commandEncoder.setBuffer(debugCounter, offset: 0, index: 10)
            
            let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
            let threadGroups = MTLSize(
                width: (anchor.faceCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1
            )
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            commandEncoder.endEncoding()
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let triCount = outTriCount.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        // Clamp to capacity (defensive)
        let triangleCount = min(Int(triCount), maxTriangles)
        let vertexCount   = triangleCount * 3
        let indexCount    = triangleCount * 3

        let minU = aabbMinU.contents().bindMemory(to: UInt32.self, capacity: 3)
        let maxU = aabbMaxU.contents().bindMemory(to: UInt32.self, capacity: 3)
        let aabbMin = SIMD3<Float>(
            orderedUIntToFloat(minU[0]),
            orderedUIntToFloat(minU[1]),
            orderedUIntToFloat(minU[2])
        )
        let aabbMax = SIMD3<Float>(
            orderedUIntToFloat(maxU[0]),
            orderedUIntToFloat(maxU[1]),
            orderedUIntToFloat(maxU[2])
        )
        let bounds: BoundingBox = BoundingBox(min: aabbMin, max: aabbMax)
        
        let debugCountPointer = debugCounter.contents().bindMemory(to: UInt32.self, capacity: debugSlots)
        var debugCountValue: [UInt32] = []
        for i in 0..<debugSlots {
            debugCountValue.append(debugCountPointer.advanced(by: i).pointee)
        }

        
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexOffset: 0,
                indexCount: indexCount,
                topology: .triangle,
                materialIndex: 0,
                bounds: bounds
            )
        ])
        self.mesh = mesh
        self.vertexCount = vertexCount
        self.indexCount = indexCount
    }
    
    @inline(__always)
    private func floatToOrderedUInt(_ f: Float) -> UInt32 {
        let u = f.bitPattern
        return (u & 0x8000_0000) != 0 ? ~u : (u | 0x8000_0000)
    }

    @inline(__always)
    private func orderedUIntToFloat(_ u: UInt32) -> Float {
        let raw = (u & 0x8000_0000) != 0 ? (u & ~0x8000_0000) : ~u
        return Float(bitPattern: raw)
    }
    
    /**
        Function to create MTLTexture from CVPixelBuffer.
     */
    @inline(__always)
    private func getSegmentationMTLTexture(segmentationPixelBuffer: CVPixelBuffer) throws -> MTLTexture {
        let width  = CVPixelBufferGetWidth(segmentationPixelBuffer)
        let height = CVPixelBufferGetHeight(segmentationPixelBuffer)
        
        guard let pixelFormat: MTLPixelFormat = segmentationPixelBuffer.metalPixelFormat() else {
            throw SegmentationMeshRecordError.segmentationBufferFormatNotSupported
        }
        
        var segmentationTextureRef: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            self.context.textureCache,
            segmentationPixelBuffer,
            nil,
            pixelFormat,
            width,
            height,
            0,
            &segmentationTextureRef
        )
        guard status == kCVReturnSuccess, let segmentationTexture = segmentationTextureRef,
              let texture = CVMetalTextureGetTexture(segmentationTexture) else {
            throw SegmentationMeshRecordError.segmentationTextureError
        }
        return texture
    }
    
    /**
     Function to create MTLTexture from CIImage using a command buffer.
     */
    private func getSegmentationMTLTexture(segmentationImage: CIImage, commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        let mtlDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: Int(segmentationImage.extent.width), height: Int(segmentationImage.extent.height),
            mipmapped: false
        )
        mtlDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let segmentationTexture = self.context.device.makeTexture(descriptor: mtlDescriptor) else {
            throw SegmentationMeshRecordError.segmentationTextureError
        }
        /// Fixing mirroring issues by orienting the image before rendering to texture
        let segmentationImageOriented = segmentationImage.oriented(.downMirrored)
        self.context.ciContextNoColorSpace.render(
            segmentationImageOriented,
            to: segmentationTexture,
            commandBuffer: commandBuffer,
            bounds: segmentationImage.extent,
            colorSpace: CGColorSpaceCreateDeviceRGB() // Dummy color space
        )
        return segmentationTexture
    }
    
    /**
        Function to create MTLTexture from CIImage using a CIContext.
     */
    private func getSegmentationMTLTexture(
        segmentationImage: CIImage, ciContext: CIContext, textureLoader: MTKTextureLoader
    ) throws -> MTLTexture {
        let mtlDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: Int(segmentationImage.extent.width), height: Int(segmentationImage.extent.height),
            mipmapped: false
        )
        mtlDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let cgImage = ciContext.createCGImage(segmentationImage, from: segmentationImage.extent) else {
            throw SegmentationMeshRecordError.segmentationTextureError
        }
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        return try textureLoader.newTexture(cgImage: cgImage, options: options)
    }
    
    static func getAccessibilityFeatureMeshClassificationParams(
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> AccessibilityFeatureMeshClassificationParams {
        let accessibilityFeatureMeshClassificationLookupTable = getAccessibilityFeatureMeshClassificationLookupTable(
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let accessibilityFeatureClassLabelValue: UInt8 = accessibilityFeatureClass.labelValue
        var accessibilityMeshClassificationParams = AccessibilityFeatureMeshClassificationParams()
        accessibilityMeshClassificationParams.labelValue = accessibilityFeatureClassLabelValue
        try accessibilityFeatureMeshClassificationLookupTable.withUnsafeBufferPointer { ptr in
            try withUnsafeMutableBytes(of: &accessibilityMeshClassificationParams) { bytes in
                guard let srcPtr = ptr.baseAddress, let dst = bytes.baseAddress else {
                    throw SegmentationMeshRecordError.accessibilityFeatureClassificationParamsError
                }
                let byteCount = accessibilityFeatureMeshClassificationLookupTable.count * MemoryLayout<UInt32>.stride
                dst.copyMemory(from: srcPtr, byteCount: byteCount)
            }
        }
        return accessibilityMeshClassificationParams
    }
    
    /**
     Return an array of booleans for metal, indicating which accessibility feature classes are to be considered.
     If the accessibilityFeatureClass.meshClassification is empty, all classes are considered valid.
     */
    static func getAccessibilityFeatureMeshClassificationLookupTable(
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) -> [UInt32] {
        // MARK: Assuming a maximum of 256 classes
        var lookupTable = [UInt32](repeating: 0, count: 256)
        let accessibilityFeatureMeshClassification: Set<ARMeshClassification> = accessibilityFeatureClass.meshClassification
        if accessibilityFeatureMeshClassification.isEmpty {
            lookupTable = [UInt32](repeating: 1, count: 256)
        } else {
            for cls in accessibilityFeatureMeshClassification {
                let index = Int(cls.rawValue)
                lookupTable[index] = 1
            }
        }
        return lookupTable
    }
    
    static func createDescriptor(meshGPUSnapshot: MeshGPUSnapshot) -> LowLevelMesh.Descriptor {
        let vertexCount = meshGPUSnapshot.anchors.values.reduce(0) { $0 + $1.vertexCount }
        let indexCount = meshGPUSnapshot.anchors.values.reduce(0) { $0 + $1.indexCount }
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: meshGPUSnapshot.vertexOffset)
        ]
        descriptor.vertexLayouts = [
            .init(bufferIndex: 0, bufferStride: meshGPUSnapshot.vertexStride)
        ]
        // MARK: Assuming uint32 for indices
        descriptor.indexType = .uint32
        // Adding extra capacity to reduce reallocations
        descriptor.vertexCapacity = vertexCount * 10
        descriptor.indexCapacity = indexCount * 10
        return descriptor
    }
    
    static func generateEntity(mesh: LowLevelMesh, color: UIColor, opacity: Float, name: String) throws -> ModelEntity {
        let resource = try MeshResource(from: mesh)
        var material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))
        material.triangleFillMode = .fill
        let entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = name
        return entity
    }
}
