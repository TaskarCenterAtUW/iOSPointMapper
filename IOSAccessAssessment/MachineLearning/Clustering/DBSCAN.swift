//
//  DBSCAN.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/20/25.
//

enum DBSCANError: Error, LocalizedError {
    case invalidMinimumNumberOfPoints
    
    var localizedDescription: String? {
        switch self {
        case .invalidMinimumNumberOfPoints:
            return "The minimum number of points must be non-negative."
        }
    }
}

/**
 A density-based, non-parametric clustering algorithm
 Reference: https://github.com/mattt/DBSCAN

 Given a set of points in some space,
 this algorithm groups points with many nearby neighbors
 and marks points in low-density regions as outliers.
 
 TODO: Move the logic to Metal for performance improvements.
 */
struct DBSCAN<Value: Equatable> {
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
    
    private var epsilon: Double
    private var minimumNumberOfPoints: Int
    private var distanceFunction: (Value, Value) throws -> Double
    
    init(epsilon: Double, minimumNumberOfPoints: Int, distanceFunction: @escaping (Value, Value) throws -> Double) {
        self.epsilon = epsilon
        self.minimumNumberOfPoints = minimumNumberOfPoints
        self.distanceFunction = distanceFunction
    }

    /**
     Clusters values according to the specified parameters.

     - Parameters:
       - epsilon: The maximum distance from a specified value
                  for which other values are considered to be neighbors.
       - minimumNumberOfPoints: The minimum number of points
                                required to form a dense region.
       - distanceFunction: A function that computes
                           the distance between two values.
     - Throws: Rethrows any errors produced by `distanceFunction`.
     - Returns: A tuple containing an array of clustered values
                and an array of outlier values.
    */
    public func fit(values: [Value]) throws -> (clusters: [[Value]], outliers: [Value]) {
        guard (minimumNumberOfPoints >= 0) else {
            throw DBSCANError.invalidMinimumNumberOfPoints
        }

        let points = values.map { Point($0) }

        var currentLabel = 0
        for point in points {
            guard point.label == nil else { continue }

            var neighbors = try points.filter { try distanceFunction(point.value, $0.value) < epsilon }
            if neighbors.count >= minimumNumberOfPoints {
                defer { currentLabel += 1 }
                point.label = currentLabel

                while !neighbors.isEmpty {
                    let neighbor = neighbors.removeFirst()
                    guard neighbor.label == nil else { continue }

                    neighbor.label = currentLabel

                    let n1 = try points.filter { try distanceFunction(neighbor.value, $0.value) < epsilon }
                    if n1.count >= minimumNumberOfPoints {
                        neighbors.append(contentsOf: n1)
                    }
                }
            }
        }

        var clusters: [[Value]] = []
        var outliers: [Value] = []

        for (label, points) in Dictionary(grouping: points, by: { $0.label }) {
            let values = points.map { $0.value }
            if label == nil {
                outliers.append(contentsOf: values)
            } else {
                clusters.append(values)
            }
        }

        return (clusters, outliers)
    }
}
