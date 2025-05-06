//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI
import DequeModule

class SharedImageData: ObservableObject {
    @Published var cameraImage: CIImage?
    
    @Published var isLidarAvailable: Bool = false
    @Published var depthImage: CIImage?
    
    // Overall segmentation image with all classes (labels)
    @Published var segmentationLabelImage: CIImage?
    @Published var segmentedIndices: [Int] = []
    @Published var detectedObjects: [UUID: DetectedObject] = [:]
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
        self.depthImage = nil
        
        self.segmentedIndices = []
        self.classImages = []
        
        self.segmentationFrames = []
        
        self.isLidarAvailable = checkLidarAvailability()
    }
    
    func appendFrame(frame: CIImage) {
        processingQueue.async {
            if (Float(self.segmentationFrames.count)/Float(self.maxCapacity) > self.thresholdRatio) {
                self.dropAlternateFrames()
            }
            self.segmentationFrames.append(frame)
//            print("Current frame count: \(self.segmentationFrames.count)")
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
