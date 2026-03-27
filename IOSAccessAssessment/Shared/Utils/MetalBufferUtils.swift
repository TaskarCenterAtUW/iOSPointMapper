//
//  MetalBufferUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//

import RealityKit
import Metal
import simd

enum MetalBufferUtilsError: Error, LocalizedError {
    case bufferTooSmall(expected: Int, actual: Int)
    case bufferCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .bufferTooSmall(let expected, let actual):
            return "The provided buffer is too small. Expected at least \(expected) bytes, but got \(actual) bytes."
        case .bufferCreationFailed:
            return "Failed to create Metal buffer."
        }
    }
}


struct MetalBufferUtils {
    static let defaultBufferSize: Int = 1024
    
    @inline(__always)
    static func copyContiguous(srcPtr: UnsafeRawPointer, dst: MTLBuffer, byteCount: Int) throws {
        guard byteCount <= dst.length else {
            throw MetalBufferUtilsError.bufferTooSmall(expected: byteCount, actual: dst.length)
        }
        let dstPtr = dst.contents()
        dstPtr.copyMemory(from: srcPtr, byteCount: byteCount)
    }
    
    @inline(__always)
    static func copyStrided(count: Int, srcPtr: UnsafeRawPointer, srcStride: Int,
                     dst: MTLBuffer, elemSize: Int) throws {
        guard count * elemSize <= dst.length else {
            throw MetalBufferUtilsError.bufferTooSmall(expected: count * elemSize, actual: dst.length)
        }
        let dstPtr = dst.contents()
        for i in 0..<count {
            let srcElemPtr = srcPtr.advanced(by: i * srcStride)
            let dstElemPtr = dstPtr.advanced(by: i * elemSize)
            dstElemPtr.copyMemory(from: srcElemPtr, byteCount: elemSize)
        }
    }
    
    @inline(__always)
    static func ensureCapacity(device: MTLDevice, buf: inout MTLBuffer, requiredBytes: Int) throws {
        if buf.length < requiredBytes {
            let newCapacity = nextCap(requiredBytes)
            buf = try makeBuffer(device: device, length: newCapacity, options: .storageModeShared)
        }
    }
    
    @inline(__always)
    static func makeBuffer(device: MTLDevice, length: Int, options: MTLResourceOptions = .storageModeShared) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: options) else {
            throw MetalBufferUtilsError.bufferCreationFailed
        }
        return buffer
    }
    
    /**
    Calculate the next power-of-two capacity greater than or equal to needed
     */
    @inline(__always)
    static func nextCap(_ needed: Int, minimum: Int = 1024) -> Int {
        let maximum: Int = Int.max >> 2
        if needed > maximum {
            return Int.max
        }
        var c = max(needed, minimum)
        c -= 1; c |= c>>1; c |= c>>2; c |= c>>4; c |= c>>8; c |= c>>16
        return c + 1
    }
}
