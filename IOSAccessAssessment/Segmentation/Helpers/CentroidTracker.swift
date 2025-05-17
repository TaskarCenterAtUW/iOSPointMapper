//
//  CentroidTracker.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/7/25.
//

import OrderedCollections
import simd

class CentroidTracker {
    private var nextObjectID: UUID;
    var detectedObjectMap: OrderedDictionary<UUID, DetectedObject>;
    var disappearedObjectMap: OrderedDictionary<UUID, Int>;
    
    var maxDisappeared: Int;
    // TODO: Currently, the distance threshold is very arbitrary.
    // We need to figure out a more systemative way to determine this.
    // It would ideally depend upon not just the distance between the centroids, but also the size of the objects.
    var distanceThreshold: Float;
    
    init(maxDisappeared: Int = 5, distanceThreshold: Float = 0.5) {
        self.nextObjectID = UUID()
        self.detectedObjectMap = OrderedDictionary()
        self.disappearedObjectMap = OrderedDictionary()
        
        self.maxDisappeared = maxDisappeared
        self.distanceThreshold = distanceThreshold
    }
    
    func reset() {
        self.nextObjectID = UUID()
        self.detectedObjectMap.removeAll()
        self.disappearedObjectMap.removeAll()
    }
    
    func register(objectClassLabel: UInt8, objectCentroid: CGPoint, objectNormalizedPoints: Array<SIMD2<Float>>,
                  objectBoundingBox: CGRect, area: Float, perimeter: Float, isCurrent: Bool) {
        let object = DetectedObject(classLabel: objectClassLabel, centroid: objectCentroid, boundingBox: objectBoundingBox, normalizedPoints: objectNormalizedPoints, area: area, perimeter: perimeter, isCurrent: isCurrent)
        self.detectedObjectMap[nextObjectID] = object
        self.disappearedObjectMap[nextObjectID] = 0
        
        nextObjectID = UUID()
    }
    
    func deregister(objectID: UUID) {
        self.detectedObjectMap.removeValue(forKey: objectID)
        self.disappearedObjectMap.removeValue(forKey: objectID)
    }
    
    /**
        Updates the tracker with the current list of detected objects.
     
    TODO: To note, the following code has not been well tested. Need to test this logic in a more controlled environment.
     For now, we got with the assumption that this works as expected, and continue with the rest of the implementation
     
     TODO: Have a better performance assessment of this update method.

     */
    func update(objects: Array<DetectedObject>, transformMatrix: simd_float3x3?) -> Void {
        /**
         If object list is empty, increment the disappeared count for each object
         */
        if (objects.isEmpty) {
            for (objectID, objectDisappearCount) in self.disappearedObjectMap {
                self.disappearedObjectMap[objectID] = objectDisappearCount + 1;
                
                if (objectDisappearCount >= self.maxDisappeared) {
                    self.deregister(objectID: objectID);
                }
            }
            return
        }
        
        /**
            If the transform matrix is not identity, we need to transform the centroids of the original objects to the new coordinate system.
         */
        if let transformMatrix = transformMatrix {
            transformObjectCentroids(using: transformMatrix);
        }
        
        /**
         If the current object list is empty, only register the new objects
         */
        if (self.detectedObjectMap.isEmpty) {
            for object in objects {
                self.register(objectClassLabel: object.classLabel, objectCentroid: object.centroid,
                              objectNormalizedPoints: object.normalizedPoints, objectBoundingBox: object.boundingBox,
                              area: object.area, perimeter: object.perimeter, isCurrent: object.isCurrent);
            }
            return
        }
        
        /**
         Otherwise, we need to match the objects in the current list with the existing objects
         */
        let objectIDs = Array(self.detectedObjectMap.keys);
        
        /**
         Compute the distance matrix between the existing objects and the new objects.         
         */
        let detectedObjects = Array(self.detectedObjectMap.values.map { $0 });
        let distanceMatrix = computeDistanceMatrix(detectedObjects: detectedObjects, inputObjects: objects);
        let rowCount = distanceMatrix.count;
        let colCount = distanceMatrix[0].count;
        
        /**
         Get the row and column indices of the minimum distance in the distance matrix.
         */
        // Get the minimum distance in each row and store (rowIndex, minValue)
        let rowMinPairs: [(row: Int, minVal: Float)] = distanceMatrix.enumerated().map { (i, row) in
            return (i, row.min() ?? Float.infinity)
        }
        // Sort rows based on their min distance values (ascending)
        let rows: [Int] = rowMinPairs.sorted(by: { $0.minVal < $1.minVal }).map { $0.row }
        // For each sorted row, find the column index of the smallest distance
        let cols: [Int] = rows.map { rowIndex in
            distanceMatrix[rowIndex].enumerated().min(by: { $0.element < $1.element })?.offset ?? -1
        }
        let minPairs = zip(rows, cols)
        
        var usedRows = Set<Int>()
        var usedCols = Set<Int>()
        
        /**
            Loop through the minimum pairs and match the objects
         */
        var matches: Int = 0
        for (row, col) in minPairs {
            // Check if the row and column are already used
            if (usedRows.contains(row) || usedCols.contains(col)) {
                continue
            }
            // Check if the distance is within the threshold
            if (distanceMatrix[row][col] > self.distanceThreshold) {
                continue
            }
            
            // Else, we have a match
            let objectID = objectIDs[row]
            self.detectedObjectMap[objectID] = objects[col]
            self.disappearedObjectMap[objectID] = 0
            
            usedRows.insert(row)
            usedCols.insert(col)
            matches += 1
        }
        /**
         Get the unused rows and columns
         */
        let unusedRows = Set(0..<rowCount).subtracting(usedRows)
        let unusedCols = Set(0..<colCount).subtracting(usedCols)
        
        /**
         If there are any unused rows, increment the disappeared count for those objects and check if they need to be deregistered
         */
        for row in unusedRows {
            let objectID = objectIDs[row]
            self.detectedObjectMap[objectID]?.isCurrent = false // Mark the object as not current
            self.disappearedObjectMap[objectID] = (self.disappearedObjectMap[objectID] ?? 0) + 1
            
            if ((self.disappearedObjectMap[objectID] ?? 0) >= self.maxDisappeared) {
                self.deregister(objectID: objectID)
            }
        }
        /**
         If there are any unused columns, register them as new objects
         */
        for col in unusedCols {
            let object = objects[col]
            self.register(objectClassLabel: object.classLabel, objectCentroid: object.centroid,
                          objectNormalizedPoints: object.normalizedPoints, objectBoundingBox: object.boundingBox,
                          area: object.area, perimeter: object.perimeter, isCurrent: false) // Mark the object as not current
        }
        
        return
    }
    
    private func getCentroidDistance(centroid1: CGPoint, centroid2: CGPoint) -> Float {
        let dx = Float(centroid1.x - centroid2.x)
        let dy = Float(centroid1.y - centroid2.y)
        return sqrt(dx * dx + dy * dy)
    }
    
    private func computeDistanceMatrix(detectedObjects: [DetectedObject], inputObjects: [DetectedObject]) -> [[Float]] {
        return detectedObjects.map { obj in
            inputObjects.map { input in
                if obj.classLabel != input.classLabel {
                    return Float.infinity // Different classes, no match
                }
                return getCentroidDistance(centroid1: obj.centroid, centroid2: input.centroid)
            }
        }
    }
}


/**
    A convenience method to update the tracker with transformed objects.
 This method applies a warp transform to the centroids of the detected objects before updating the tracker.
 This method is redundantly defined here, and will later be moved to a centralized utility class for homography transformations.
 */
extension CentroidTracker {
    /// Transforms the input point using the provided warpTransform matrix.
    private func warpedPoint(_ point: CGPoint, using warpTransform: simd_float3x3) -> CGPoint {
        let vector0 = SIMD3<Float>(x: Float(point.x), y: Float(point.y), z: 1)
        let vector1 = warpTransform * vector0
        return CGPoint(x: CGFloat(vector1.x / vector1.z), y: CGFloat(vector1.y / vector1.z))
    }
    
    /**
     FIXME: There is a risk with this method: For the objects that are not mapped to the new objects, we do not retain consistent details.
     While the centroid is updated, the bounding box and normalized points are not updated.
     Not to mention, we do not know which image they belong to.
     For now, this is not a problem since we will not be using these objects for any further processing.
     */
    private func transformObjectCentroids(using transformMatrix: simd_float3x3) {
        /*
            Applies a warp transform to the centroids of the detected objects.
         Need to transpose the matrix to apply it correctly to the centroids since SIMD3 is column-major order.
         Also, the homography matrix is in pixel coordinates, while the centroids are in normalized coordinates.
         So we need to make the transformation in normalized coordinates.
         */
        let scaledTransform = self.normalizeHomographyMatrix(transformMatrix)
        let warpTransform = scaledTransform.transpose
        for (objectID, object) in self.detectedObjectMap {
            let transformedCentroid = warpedPoint(object.centroid, using: warpTransform)
            let transformedObject = DetectedObject(classLabel: object.classLabel,
                                                   centroid: transformedCentroid,
                                                   boundingBox: object.boundingBox,
                                                   normalizedPoints: object.normalizedPoints,
                                                   area: object.area,
                                                   perimeter: object.perimeter,
                                                   isCurrent: object.isCurrent)
            self.detectedObjectMap[objectID] = transformedObject
        }
    }
    
    private func normalizeHomographyMatrix(_ matrix: simd_float3x3) -> simd_float3x3 {
        let width = Float(Constants.ClassConstants.inputSize.width)
        let height = Float(Constants.ClassConstants.inputSize.height)
        
        // S: scales normalized → pixel coordinates
        let S = simd_float3x3(rows: [
            SIMD3<Float>(width,     0,     0),
            SIMD3<Float>(    0, height,     0),
            SIMD3<Float>(    0,     0,     1)
        ])
        
        // S_inv: scales pixel → normalized coordinates
        let S_inv = simd_float3x3(rows: [
            SIMD3<Float>(1/width,       0,     0),
            SIMD3<Float>(      0, 1/height,     0),
            SIMD3<Float>(      0,       0,     1)
        ])
        
        let normalizedMatrix = S_inv * matrix * S
        return normalizedMatrix
    }
}
