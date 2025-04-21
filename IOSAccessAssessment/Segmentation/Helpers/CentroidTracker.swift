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
    var objects: OrderedDictionary<UUID, DetectedObject>;
    var disappearedObjects: OrderedDictionary<UUID, Int>;
    
    var maxDisappeared: Int;
    var distanceThreshold: Float;
    
    init(maxDisappeared: Int = 5, distanceThreshold: Float = 0.2) {
        self.nextObjectID = UUID()
        self.objects = OrderedDictionary()
        self.disappearedObjects = OrderedDictionary()
        
        self.maxDisappeared = maxDisappeared
        self.distanceThreshold = distanceThreshold
    }
    
    func reset() {
        self.nextObjectID = UUID()
        self.objects.removeAll()
        self.disappearedObjects.removeAll()
    }
    
    func register(objectClassLabel: UInt8, objectCentroid: CGPoint, objectNormalizedPoints: Array<SIMD2<Float>>,
                  objectBoundingBox: CGRect, isCurrent: Bool) {
        let object = DetectedObject(classLabel: objectClassLabel, centroid: objectCentroid, boundingBox: objectBoundingBox, normalizedPoints: objectNormalizedPoints, isCurrent: isCurrent)
        self.objects[nextObjectID] = object
        self.disappearedObjects[nextObjectID] = 0
        
        nextObjectID = UUID()
    }
    
    func deregister(objectID: UUID) {
        self.objects.removeValue(forKey: objectID)
        self.disappearedObjects.removeValue(forKey: objectID)
    }
    
    /**
        Updates the tracker with the current list of detected objects.
     
    TODO: To note, the following code has not been well tested. Need to test this logic in a more controlled environment.
     For now, we got with the assumption that this works as expected, and continue with the rest of the implementation

     */
    func update(objectsList: Array<DetectedObject>, transformMatrix: simd_float3x3?) -> Void {
        /**
         If object list is empty, increment the disappeared count for each object
         */
        if (objectsList.isEmpty) {
            for (objectID, objectDisappearCount) in self.disappearedObjects {
                self.disappearedObjects[objectID] = objectDisappearCount + 1;
                
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
        if (self.objects.isEmpty) {
            for object in objectsList {
                self.register(objectClassLabel: object.classLabel, objectCentroid: object.centroid,
                              objectNormalizedPoints: object.normalizedPoints, objectBoundingBox: object.boundingBox,
                              isCurrent: object.isCurrent);
            }
            return
        }
        
        /**
         Otherwise, we need to match the objects in the current list with the existing objects
         */
        let objectIDs = Array(self.objects.keys);
        
        /**
         Compute the distance matrix between the existing objects and the new objects.         
         */
        let objects = Array(self.objects.values.map { $0 });
        let inputObjects = Array(objectsList.map { $0 });
        let distanceMatrix = computeDistanceMatrix(objects: objects, inputObjects: inputObjects);
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
            self.objects[objectID] = objectsList[col]
            self.disappearedObjects[objectID] = 0
            
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
            self.objects[objectID]?.isCurrent = false // Mark the object as not current
            self.disappearedObjects[objectID] = (self.disappearedObjects[objectID] ?? 0) + 1
            
            if ((self.disappearedObjects[objectID] ?? 0) >= self.maxDisappeared) {
                self.deregister(objectID: objectID)
            }
        }
        /**
         If there are any unused columns, register them as new objects
         */
        for col in unusedCols {
            let object = objectsList[col]
            self.register(objectClassLabel: object.classLabel, objectCentroid: object.centroid,
                          objectNormalizedPoints: object.normalizedPoints, objectBoundingBox: object.boundingBox,
                          isCurrent: false) // Mark the object as not current
        }
        
//        print("Number of matches: ", matches)
//        print("Number of objects: ", self.objects.count)
//        print("Number of objects on track to disappear: ", self.disappearedObjects.count(where: { $0.value > 0 }))
        
        return
    }
    
    private func getCentroidDistance(centroid1: CGPoint, centroid2: CGPoint) -> Float {
        let dx = Float(centroid1.x - centroid2.x)
        let dy = Float(centroid1.y - centroid2.y)
        return sqrt(dx * dx + dy * dy)
    }
    
    private func computeDistanceMatrix(objects: [DetectedObject], inputObjects: [DetectedObject]) -> [[Float]] {
        return objects.map { obj in
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
    
    private func transformObjectCentroids(using transformMatrix: simd_float3x3) {
        /*
            Applies a warp transform to the centroids of the detected objects.
         Need to transpose the matrix to apply it correctly to the centroids since SIMD3 is column-major order.
         */
        let warpTransform = transformMatrix.transpose
        for (objectID, object) in self.objects {
            let transformedCentroid = warpedPoint(object.centroid, using: warpTransform)
            let transformedObject = DetectedObject(classLabel: object.classLabel,
                                                   centroid: transformedCentroid,
                                                   boundingBox: object.boundingBox,
                                                   normalizedPoints: object.normalizedPoints,
                                                   isCurrent: object.isCurrent)
            self.objects[objectID] = transformedObject
        }
    }
}
