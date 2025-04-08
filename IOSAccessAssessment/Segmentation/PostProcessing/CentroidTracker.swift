//
//  CentroidTracker.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/7/25.
//

import OrderedCollections

struct TrackedObject {
    var name: String
    var centroid: (Int, Int)
    var polygon: [CGPoint]
    var location: (Float, Float)
    var heading: Float
    var width: Float
}

class CentroidTracker {
    
    private var nextObjectID: Int;
    private var objects: OrderedDictionary<Int, TrackedObject>;
    private var disappearedObjects: OrderedDictionary<Int, Int>;
    
    var maxDisappeared: Int;
    var distanceThreshold: Float;
    
    init(maxDisappeared: Int, distanceThreshold: Float = 50.0) {
        self.nextObjectID = 0
        self.objects = OrderedDictionary()
        self.disappearedObjects = OrderedDictionary()
        
        self.maxDisappeared = maxDisappeared
        self.distanceThreshold = distanceThreshold
    }
    
    func register(object_name: String, object_centroid: (Int, Int), object_polygon: Array<CGPoint>,
                  object_location: (Float, Float), object_heading: Float, object_width: Float) {
        let object = TrackedObject(name: object_name, centroid: object_centroid, polygon: object_polygon,
                                   location: object_location, heading: object_heading, width: object_width);
        self.objects[nextObjectID] = object
        self.disappearedObjects[nextObjectID] = 0
        
        nextObjectID += 1
    }
    
    func deregister(objectID: Int) {
        self.objects.removeValue(forKey: objectID)
        self.disappearedObjects.removeValue(forKey: objectID)
    }
    
    func update(objectsList: Array<TrackedObject>) ->
    (objects: OrderedDictionary<Int, TrackedObject>, disappearedObjects: OrderedDictionary<Int, Int>) {
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
                self.register(object_name: object.name, object_centroid: object.centroid,
                              object_polygon: object.polygon, object_location: object.location,
                              object_heading: object.heading, object_width: object.width);
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
        // Step 1: Get the minimum distance in each row and store (rowIndex, minValue)
        var rowMinPairs: [(row: Int, minVal: Float)] = distanceMatrix.enumerated().map { (i, row) in
            return (i, row.min() ?? Float.infinity)
        }
        // Step 2: Sort rows based on their min distance values (ascending)
        let rows = rowMinPairs.sorted(by: { $0.minVal < $1.minVal }).map { $0.row }
        // Step 3: For each sorted row, find the column index of the smallest distance
        let cols: [Int] = rows.map { rowIndex in
            D[rowIndex].enumerated().min(by: { $0.element < $1.element })?.offset ?? -1
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
            self.disappearedObjects[objectID] = self.disappearedObjects[objectID] + 1
            
            if (self.disappearedObjects[objectID] >= self.maxDisappeared) {
                self.deregister(objectID: objectID)
            }
        }
        /**
         If there are any unused columns, register them as new objects
         */
        for col in unusedCols {
            let object = objectsList[col]
            self.register(object_name: object.name, object_centroid: object.centroid,
                          object_polygon: object.polygon, object_location: object.location,
                          object_heading: object.heading, object_width: object.width);
        }
        
        return (objects: self.objects, disappearedObjects: self.disappearedObjects)
    }
    
    private func getCentroidDistance(centroid1: (Int, Int), centroid2: (Int, Int)) -> Float {
        let dx = Float(centroid1.0 - centroid2.0)
        let dy = Float(centroid1.1 - centroid2.1)
        return sqrt(dx * dx + dy * dy)
    }
    
    private func computeDistanceMatrix(objectCentroids: [(Int, Int)], inputCentroids: [(Int, Int)]) -> [[Float]] {
        return objectCentroids.map { obj in
            inputCentroids.map { input in
                getCentroidDistance(centroid1: obj, centroid2: input)
            }
        }
    }
    
}
