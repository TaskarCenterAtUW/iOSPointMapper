//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI
import DequeModule

class SharedImageData: ObservableObject {
    // MARK: Eventually, move on to using CIImage directly
    // as there is no reason to be using CGImage other than crop to center
    // we can find CIImage-specific method for this as well,
    // else we can do a conversion to CVPixelBuffer on the fly when required
    @Published var cameraImage: CGImage?
    @Published var depthData: CVPixelBuffer?
    
    @Published var segmentedIndices: [Int] = []
    // Single segmentation image for each class
    @Published var classImages: [CIImage] = []
    
    var segmentationFrames: Deque<CIImage> = []
    private let processingQueue = DispatchQueue(label: "com.example.sharedimagedata.queue", qos: .utility)
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
    
    func appendFrame(frame: CIImage) {
        DispatchQueue.main.async {
            if (Float(self.segmentationFrames.count)/Float(self.maxCapacity) > self.thresholdRatio) {
                self.dropAlternateFrames()
            }
            self.segmentationFrames.append(frame)
            print("Current frame count: \(self.segmentationFrames.count)")
        }
    }
    
    private func dropAlternateFrames() {
        var newFrames = Deque<CIImage>()
        for (index, frame) in self.segmentationFrames.enumerated() {
            // Keep every alternate frame (even indices)
            if index % 2 == 0 {
                newFrames.append(frame)
            }
        }
        self.segmentationFrames = newFrames
    }
    
    func getFrames() -> [CIImage] {
        var frames: [CIImage] = []
        processingQueue.sync {
            frames = Array(self.segmentationFrames)
        }
        return frames
    }
}
