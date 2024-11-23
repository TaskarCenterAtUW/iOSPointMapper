//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI

class SharedImageData: ObservableObject {
    @Published var cameraImage: UIImage?
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
