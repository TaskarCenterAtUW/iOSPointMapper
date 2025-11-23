//
//  ConnectedComponents.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/21/25.
//

/**
    A clustering algorithm that groups values based on their connectivity using a user-defined adjacency function.
 
    TODO: Move the logic to Metal for performance improvements.
 */
struct ConnectedComponents<Value: Equatable> {
    private class Point: Equatable {
        typealias Label = Int

        let value: Value
        var label: Label?

        init(_ value: Value) {
            self.value = value
        }

        static func == (lhs: Point, rhs: Point) -> Bool {
            return lhs.value == rhs.value
        }
    }
    
    private var minimumNumberOfPoints: Int
    private var adjacencyFunction: (Value, Value, Float) throws -> Bool
    private var adjacencyThreshold: Float = 0.0
    
    /**
     Initializes the ConnectedComponents clustering algorithm.
     
     - Parameters:
        - minimumNumberOfPoints: The minimum number of points required to form a dense region (cluster).
        - adjacencyFunction: A function that checks if two values are adjacent (connected).
            If they are not, checks if their distance is within a threshold.
     */
    init(
        minimumNumberOfPoints: Int,
        adjacencyFunction: @escaping (Value, Value, Float) throws -> Bool, adjacencyThreshold: Float = 0.0
    ) {
        self.minimumNumberOfPoints = minimumNumberOfPoints
        self.adjacencyFunction = adjacencyFunction
        self.adjacencyThreshold = adjacencyThreshold
    }
    
    /**
    Clusters values according to the specified parameters.

     - Parameters:
        - values: An array of values to be clustered.
     - Throws: Rethrows any errors produced by `distanceFunction`.
     - Returns: A tuple containing an array of clustered values
                and an array of outlier values.
    */
    public func fit(values: [Value]) throws -> (clusters: [[Value]], outliers: [Value]) {
        let points = values.map { Point($0) }

        var currentLabel = 0
        for point in points {
            guard point.label == nil else { continue }
            
            var neighbors = try points.filter {
                try adjacencyFunction(point.value, $0.value, adjacencyThreshold)
            }
            defer { currentLabel += 1 }
            point.label = currentLabel
            while !neighbors.isEmpty {
                let neighbor = neighbors.removeFirst()
                guard neighbor.label == nil else { continue }

                neighbor.label = currentLabel

                let n1 = try points.filter {
                    try adjacencyFunction(point.value, $0.value, adjacencyThreshold)
                }
                if n1.count >= minimumNumberOfPoints {
                    neighbors.append(contentsOf: n1)
                }
            }
        }

        var clusters: [[Value]] = []
        var outliers: [Value] = []
        
        for (label, labelPoints) in Dictionary(grouping: points, by: { $0.label }) {
            let values = labelPoints.map { $0.value }
            if (label == nil || values.count < minimumNumberOfPoints) {
                outliers.append(contentsOf: values)
            } else {
                clusters.append(values)
            }
        }

        return (clusters, outliers)
    }
}
