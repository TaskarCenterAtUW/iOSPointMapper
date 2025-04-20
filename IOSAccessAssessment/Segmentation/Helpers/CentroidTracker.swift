//
//  CentroidTracker.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/7/25.
//

import OrderedCollections

struct TrackedObject {
    var classLabel: UInt8
    var centroid: CGPoint
    var polygon: [SIMD2<Float>] // Using SIMD2<Float> for polygon points because contour detection typically returns points in this format
    var boundingBox: CGRect?
//    var location: (Float, Float)
//    var heading: Float
//    var width: Float
}

class CentroidTracker {
    private var nextObjectID: UUID;
    private var objects: OrderedDictionary<UUID, TrackedObject>;
    private var disappearedObjects: OrderedDictionary<UUID, Int>;
    
    var maxDisappeared: Int;
    var distanceThreshold: Float;
    
    init(maxDisappeared: Int, distanceThreshold: Float = 50.0) {
        self.nextObjectID = UUID()
        self.objects = OrderedDictionary()
        self.disappearedObjects = OrderedDictionary()
        
        self.maxDisappeared = maxDisappeared
        self.distanceThreshold = distanceThreshold
    }
    
    func register(objectClassLabel: UInt8, objectCentroid: CGPoint, objectPolygon: Array<SIMD2<Float>>, objectBoundingBox: CGRect? = nil) {
        let object = TrackedObject(classLabel: objectClassLabel, centroid: objectCentroid, polygon: objectPolygon, boundingBox: objectBoundingBox)
        self.objects[nextObjectID] = object
        self.disappearedObjects[nextObjectID] = 0
        
        nextObjectID = UUID()
    }
    
    func deregister(objectID: UUID) {
        self.objects.removeValue(forKey: objectID)
        self.disappearedObjects.removeValue(forKey: objectID)
    }
    
    func update(objectsList: Array<TrackedObject>) ->
    (objects: OrderedDictionary<UUID, TrackedObject>, disappearedObjects: OrderedDictionary<UUID, Int>) {
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
            return (objects: self.objects, disappearedObjects: self.disappearedObjects)
        }
        
        /**
         If the current object list is empty, only register the new objects
         */
        if (self.objects.isEmpty) {
            for object in objectsList {
                self.register(objectClassLabel: object.classLabel, objectCentroid: object.centroid,
                              objectPolygon: object.polygon, objectBoundingBox: object.boundingBox);
            }
            return (objects: self.objects, disappearedObjects: self.disappearedObjects)
        }
        
        /**
         Otherwise, we need to match the objects in the current list with the existing objects
         */
        let objectIDs = Array(self.objects.keys);
        let objectCentroids = Array(self.objects.values.map { $0.centroid });
        
        let inputObjectCentroids = Array(objectsList.map { $0.centroid });
        
        /**
         Compute the distance matrix between the existing objects and the new objects.         
         */
        let distanceMatrix = computeDistanceMatrix(objectCentroids: objectCentroids, inputCentroids: inputObjectCentroids);
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
                          objectPolygon: object.polygon, objectBoundingBox: object.boundingBox)
        }
        
        return (objects: self.objects, disappearedObjects: self.disappearedObjects)
    }
    
    private func getCentroidDistance(centroid1: CGPoint, centroid2: CGPoint) -> Float {
        let dx = Float(centroid1.x - centroid2.x)
        let dy = Float(centroid1.y - centroid2.y)
        return sqrt(dx * dx + dy * dy)
    }
    
    private func computeDistanceMatrix(objectCentroids: [CGPoint], inputCentroids: [CGPoint]) -> [[Float]] {
        return objectCentroids.map { obj in
            inputCentroids.map { input in
                getCentroidDistance(centroid1: obj, centroid2: input)
            }
        }
    }
    
}
