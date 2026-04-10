//
//  SurfaceIntegrityFromMeshExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/9/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

extension SurfaceIntegrityProcessor {
//    func getSurfaceNormalIntegrityResultFromMesh(
//        meshPolygons: [MeshPolygon],
//        plane: Plane,
//        damageDetectionResults: [DamageDetectionResult],
//        captureData: (any CaptureMeshDataProtocol),
//        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
//        deviantPointProportionThreshold: Float = Constants.SurfaceIntegrityConstants.meshDeviantPointProportionThreshold
//    ) throws -> IntegrityStatusDetails {
//    }
//    
//    func getBoundingBoxAreaIntegrityResultFromMesh(
//        meshPolygons: [MeshPolygon],
//        plane: Plane,
//        damageDetectionResults: [DamageDetectionResult],
//        captureData: (any CaptureMeshDataProtocol),
//        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
//        deviantPolygonProportion: Float = Constants.SurfaceIntegrityConstants.meshDeviantPolygonProportionThreshold
//    ) throws -> IntegrityStatusDetails {
//    }
//    
//    func getBoundingBoxSurfaceNormalIntegrityResultFromMesh(
//        meshPolygons: [MeshPolygon],
//        plane: Plane,
//        damageDetectionResults: [DamageDetectionResult],
//        captureData: (any CaptureMeshDataProtocol),
//        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
//        deviantPointProportionThreshold: Float = Constants.SurfaceIntegrityConstants.meshDeviantPointProportionThreshold
//    ) throws -> IntegrityStatusDetails {
//    }
//    
    func getSurfaceNormalIntegrityResultFromMeshCPU(
        meshPolygons: [MeshPolygon],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
        deviantPolygonProportion: Float = Constants.SurfaceIntegrityConstants.meshDeviantPolygonProportionThreshold
    ) throws -> IntegrityStatusDetails {
        let planeNormal = plane.normalVector
        var totalDeviantPolygons = 0
        var totalPolygons = 0
        for meshPolygon in meshPolygons {
            let surfaceNormal = meshPolygon.normal
            let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
            if angularDeviation > angularDeviationThreshold {
                totalDeviantPolygons += 1
            }
            totalPolygons += 1
        }
        let deviantPolygonProportion = totalPolygons > 0 ? Float(totalDeviantPolygons) / Float(totalPolygons) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantPolygonProportion > deviantPolygonProportion ? .compromised : .intact,
            details: "Deviant Polygon Proportion: \(deviantPolygonProportion * 100)%, Total Deviant Polygon: \(totalDeviantPolygons), Total Polygons: \(totalPolygons)"
        )
        return statusDetails
    }
    
    func getBoundingBoxAreaIntegrityResultFromMeshCPU(
        meshPolygons: [MeshPolygon],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        boundingBoxAreaThreshold: Float = Constants.SurfaceIntegrityConstants.meshBoundingBoxAreaThreshold
    ) throws -> IntegrityStatusDetails {
        let viewMatrix = captureData.cameraTransform.inverse
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        
        let meshPolygonCentroidPixels: [CGPoint?] = meshPolygons.map { meshPolygon in
            let centroid = meshPolygon.centroid
            return ProjectionUtils.unprojectWorldToPixel(
                worldPoint: centroid,
                viewMatrix: viewMatrix,
                cameraIntrinsics: captureData.cameraIntrinsics,
                imageSize: captureData.originalSize
            )
        }
        
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let minX = Int(boundsParams.minX)
            let maxX = Int(boundsParams.maxX)
            let minY = Int(boundsParams.minY)
            let maxY = Int(boundsParams.maxY)
            var boundingBoxArea: Float = 0.0
            for i in 0..<meshPolygons.count {
                let meshPolygon = meshPolygons[i]
                let centroidPixel = meshPolygonCentroidPixels[i]
                guard let centroidPixel else { continue }
                let centroidPixelX = Int(centroidPixel.x)
                let centroidPixelY = Int(centroidPixel.y)
                guard centroidPixelX >= minX, centroidPixelX <= maxX,
                      centroidPixelY >= minY, centroidPixelY <= maxY else {
                    continue
                }
                boundingBoxArea += meshPolygon.area
            }
            guard boundingBoxArea > boundingBoxAreaThreshold else { continue }
            deviantBoundingBoxes += 1
            boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has area above threshold. Area: \(boundingBoxArea)).\n"
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
    
    func getBoundingBoxSurfaceNormalIntegrityResultFromMeshCPU(
        meshPolygons: [MeshPolygon],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
        boundingBoxAngularStdThreshold: Float = Constants.SurfaceIntegrityConstants.meshBoundingBoxAngularStdThreshold
    ) throws -> IntegrityStatusDetails {
        let viewMatrix = captureData.cameraTransform.inverse
        let planeNormal = plane.normalVector
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        
        let meshPolygonCentroidPixels: [CGPoint?] = meshPolygons.map { meshPolygon in
            let centroid = meshPolygon.centroid
            return ProjectionUtils.unprojectWorldToPixel(
                worldPoint: centroid,
                viewMatrix: viewMatrix,
                cameraIntrinsics: captureData.cameraIntrinsics,
                imageSize: captureData.originalSize
            )
        }
        
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let minX = Int(boundsParams.minX)
            let maxX = Int(boundsParams.maxX)
            let minY = Int(boundsParams.minY)
            let maxY = Int(boundsParams.maxY)
            var angularDeviationSum: Float = 0
            var angularDeviationSquaredSum: Float = 0
            var totalPolygons = 0
            for i in 0..<meshPolygons.count {
                let meshPolygon = meshPolygons[i]
                let centroidPixel = meshPolygonCentroidPixels[i]
                guard let centroidPixel else { continue }
                let centroidPixelX = Int(centroidPixel.x)
                let centroidPixelY = Int(centroidPixel.y)
                guard centroidPixelX >= minX, centroidPixelX <= maxX,
                      centroidPixelY >= minY, centroidPixelY <= maxY else {
                    continue
                }
                let surfaceNormal = meshPolygon.normal
                let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
                angularDeviationSum += angularDeviation
                angularDeviationSquaredSum += angularDeviation * angularDeviation
                totalPolygons += 1
            }
            guard totalPolygons > 0 else { continue }
            let angularDeviationMean = angularDeviationSum / Float(totalPolygons)
            let angularDeviationVariance = (angularDeviationSquaredSum / Float(totalPolygons)) - (angularDeviationMean * angularDeviationMean)
            let angularDeviationStd = sqrt(angularDeviationVariance)
            if angularDeviationStd > boundingBoxAngularStdThreshold {
                deviantBoundingBoxes += 1
                boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has surface normal angular std above threshold. Angular Std: \(angularDeviationStd).\n"
            }
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
}
