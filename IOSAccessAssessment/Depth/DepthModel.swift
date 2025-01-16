//
//  DepthModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/15/25.
//
import SwiftUI

enum DepthError: Error, LocalizedError {
    case emptyDepth
    case invalidDepth
    
    var errorDescription: String? {
        switch self {
        case .emptyDepth:
            return "The Depth array is Empty"
        case .invalidDepth:
            return "The Depth Estimation is invalid"
        }
    }
}

struct DepthResultsOutput {
    var depthResults: CIImage
    
    init(depthResults: CIImage) {
        self.depthResults = depthResults
    }
}

class DepthModel: ObservableObject {
    @Published var depthResults: CVPixelBuffer?
    
    
}
