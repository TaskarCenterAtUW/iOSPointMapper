//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI

class SharedImageData: ObservableObject {
    // MARK: Eventually, move on to using CVPixelBuffer directly
    // as there is no reason to be using CGImage other than crop to center
    // we can find CVPixelBuffer-specific method for this as well
    @Published var cameraImage: CGImage?
    @Published var depthData: CVPixelBuffer?
    
    @Published var segmentedIndices: [Int] = []
    // Single segmentation image for each class
    @Published var classImages: [CIImage] = []
    
    func refreshData() {
        self.cameraImage = nil
        self.depthData = nil
        
        self.segmentedIndices = []
        self.classImages = []
    }
}
