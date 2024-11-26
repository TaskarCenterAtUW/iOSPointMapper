//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI
import DequeModule

class SharedImageData: ObservableObject {
    // MARK: Eventually, move on to using CVPixelBuffer directly
    // as there is no reason to be using CGImage other than crop to center
    // we can find CVPixelBuffer-specific method for this as well
    @Published var cameraImage: CGImage?
    @Published var depthData: CVPixelBuffer?
    
    @Published var segmentedIndices: [Int] = []
    // Single segmentation image for each class
    @Published var classImages: [CIImage] = []
    
    var segmentationFrames: Deque<CVPixelBuffer> = []
    var maxCapacity: Int
    var thresholdRatio: Float = 0.7
    
    init(maxCapacity: Int = 100, thresholdRatio: Float = 0.7) {
        self.maxCapacity = maxCapacity
    }
    
    func refreshData() {
        self.cameraImage = nil
        self.depthData = nil
        
        self.segmentedIndices = []
        self.classImages = []
        
        self.segmentationFrames = []
    }
    
    func appendFrame(frame: CVPixelBuffer) {
        if (Float(self.segmentationFrames.count)/Float(self.maxCapacity) > self.thresholdRatio) {
            self.dropAlternateFrames()
        }
        self.segmentationFrames.append(frame)
        print(self.segmentationFrames.count)
    }
    
    private func dropAlternateFrames() {
        var newFrames = Deque<CVPixelBuffer>()
        for (index, frame) in self.segmentationFrames.enumerated() {
            // Keep every alternate frame (even indices)
            if index % 2 == 0 {
                newFrames.append(frame)
            }
        }
        self.segmentationFrames = newFrames
    }
}
