//
//  HomographyRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import Vision
import simd

struct HomographyRequestProcessor {    
    /// Computes the homography transform for the reference image and the floating image.
    //      MARK: It seems like the Homography transformation is done the other way around. (floatingImage is the target)
    func getHomographyTransform(referenceImage: CIImage, floatingImage: CIImage, orientation: CGImagePropertyOrientation = .up) -> simd_float3x3? {
        do {
            let transformRequest = VNHomographicImageRegistrationRequest(targetedCIImage: referenceImage, orientation: orientation)
            let transformRequestHandler = VNImageRequestHandler(ciImage: floatingImage, orientation: orientation, options: [:])
            try transformRequestHandler.perform([transformRequest])
            guard let transformResult = transformRequest.results else {return nil}
            let transformMatrix = transformResult.first?.warpTransform
            guard let matrix = transformMatrix else {
                print("Homography transform matrix is nil")
                return nil
            }
            return matrix
        }
        catch {
            print("Error processing homography transform request: \(error)")
            return nil
        }
    }
    
    /// Transforms the input point using the provided warpTransform matrix.
    private func warpedPoint(_ point: CGPoint, using warpTransform: simd_float3x3) -> CGPoint {
        let vector0 = SIMD3<Float>(x: Float(point.x), y: Float(point.y), z: 1)
        let vector1 = warpTransform * vector0
        return CGPoint(x: CGFloat(vector1.x / vector1.z), y: CGFloat(vector1.y / vector1.z))
    }
    
    func transformObjectCentroids(for detectedObjects: [DetectedObject], using transformMatrix: simd_float3x3) -> [DetectedObject] {
        return detectedObjects.map { object in
            let transformedCentroid = warpedPoint(object.centroid, using: transformMatrix)
            return DetectedObject(
                classLabel: object.classLabel,
                centroid: transformedCentroid,
                boundingBox: object.boundingBox,
                normalizedPoints: object.normalizedPoints,
                area: object.area,
                perimeter: object.perimeter,
                isCurrent: object.isCurrent
            )
        }
    }
    
    /// This is a quadrilateral defined by four corner points.
    private struct Quad {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
    }
    
    /// Warps the input rectangle using the warpTransform matrix, and returns the warped Quad.
    private func makeWarpedQuad(for rect: CGRect, using warpTransform: simd_float3x3) -> Quad {
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        
        let topLeft = CGPoint(x: minX, y: maxY)
        let topRight = CGPoint(x: maxX, y: maxY)
        let bottomLeft = CGPoint(x: minX, y: minY)
        let bottomRight = CGPoint(x: maxX, y: minY)
        
        let warpedTopLeft = warpedPoint(topLeft, using: warpTransform)
        let warpedTopRight = warpedPoint(topRight, using: warpTransform)
        let warpedBottomLeft = warpedPoint(bottomLeft, using: warpTransform)
        let warpedBottomRight = warpedPoint(bottomRight, using: warpTransform)
        
        return Quad(topLeft: warpedTopLeft,
                    topRight: warpedTopRight,
                    bottomLeft: warpedBottomLeft,
                    bottomRight: warpedBottomRight)
    }
    
    func transformImage(for floatingImage: CIImage, using transformMatrix: simd_float3x3) -> CIImage? {
        let quad = makeWarpedQuad(for: floatingImage.extent, using: transformMatrix)
        // Creates the alignedImage by warping the floating image using the warpTransform from the homographic observation.
        let transformParameters = [
            "inputTopLeft": CIVector(cgPoint: quad.topLeft),
            "inputTopRight": CIVector(cgPoint: quad.topRight),
            "inputBottomRight": CIVector(cgPoint: quad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: quad.bottomLeft)
        ]
        
        let transformedImage = floatingImage.applyingFilter("CIPerspectiveTransform", parameters: transformParameters)
        return transformedImage
    }
    
//    func processTransformFloatingObjectsRequest(referenceImage: CIImage, floatingImage: CIImage, floatingObjects: [DetectedObject]) -> [DetectedObject]? {
//        let start = DispatchTime.now()
//        let transformMatrix = self.getHomographyTransform(for: referenceImage, floatingImage: floatingImage)
////            let transformImage = self.transformImage(for: floatingImage, using: transformMatrix!)
//        let transformedObjects = self.transformObjectCentroids(for: floatingObjects, using: transformMatrix!)
//        let end = DispatchTime.now()
//        let timeInterval = (end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
////            print("Transform floating image time: \(timeInterval) ms")
//        return transformedObjects
//    }
}
