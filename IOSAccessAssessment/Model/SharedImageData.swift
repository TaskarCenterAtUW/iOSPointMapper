//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI
import DequeModule

class ImageData {
    var cameraImage: CIImage
    var depthImage: CIImage?
    
    var segmentationLabelImage: CIImage
    var segmentedIndices: [Int]
    var detectedObjects: [UUID: DetectedObject]
    
    init(cameraImage: CIImage, depthImage: CIImage?,
            segmentationLabelImage: CIImage, segmentedIndices: [Int],
         detectedObjects: [UUID: DetectedObject]) {
        self.cameraImage = cameraImage
        self.depthImage = depthImage
        self.segmentationLabelImage = segmentationLabelImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjects = detectedObjects
    }
}

class SharedImageData: ObservableObject {
    @Published var cameraImage: CIImage?
    
    @Published var isLidarAvailable: Bool = false
    @Published var depthImage: CIImage?
    
    // Overall segmentation image with all classes (labels)
    @Published var segmentationLabelImage: CIImage?
    // Indices of all the classes that were detected in the segmentation image
    @Published var segmentedIndices: [Int] = []
    @Published var detectedObjects: [UUID: DetectedObject] = [:]
    // Single segmentation image for each class
    @Published var classImages: [CIImage] = []
    
    var history: Deque<ImageData> = []
    private let historyQueue = DispatchQueue(label: "com.example.sharedimagedata.history.queue", qos: .utility)
    var historyMaxCapacity: Int = 5
        
    var segmentationFrames: Deque<CIImage> = []
    private let processingQueue = DispatchQueue(label: "com.example.sharedimagedata.queue", qos: .utility)
    var maxCapacity: Int
    var thresholdRatio: Float = 0.7
    
    init(maxCapacity: Int = 100, thresholdRatio: Float = 0.7, historyMaxCapacity: Int = 5) {
        self.maxCapacity = maxCapacity
        self.thresholdRatio = thresholdRatio
        self.historyMaxCapacity = historyMaxCapacity
    }
    
    func refreshData() {
        self.cameraImage = nil
        self.depthImage = nil
        
        self.segmentationLabelImage = nil
        self.segmentedIndices = []
        self.classImages = []
        self.detectedObjects = [:]
        
        self.history.removeAll()
        self.segmentationFrames.removeAll()
        
        self.isLidarAvailable = checkLidarAvailability()
    }
    
    func recordImageData(imageData: ImageData) {
        historyQueue.async {
            if self.history.count >= self.historyMaxCapacity {
                self.history.removeFirst()
            }
            self.history.append(imageData)
        }
    }
    
    func getLastImageData() -> ImageData? {
        var lastImageData: ImageData?
        historyQueue.sync {
            lastImageData = self.history.last
        }
        return lastImageData
    }
    
    func getImageDataHistory() -> [ImageData] {
        var imageDataHistory: [ImageData] = []
        historyQueue.sync {
            imageDataHistory = Array(self.history)
        }
        return imageDataHistory
    }
    
    func appendFrame(frame: CIImage) {
        func dropAlternateFrames() {
            var newFrames = Deque<CIImage>()
            for (index, frame) in self.segmentationFrames.enumerated() {
                // Keep every alternate frame (even indices)
                if index % 2 == 0 {
                    newFrames.append(frame)
                }
            }
            self.segmentationFrames = newFrames
        }
        
        processingQueue.async {
            if (Float(self.segmentationFrames.count)/Float(self.maxCapacity) > self.thresholdRatio) {
                dropAlternateFrames()
            }
            self.segmentationFrames.append(frame)
//            print("Current frame count: \(self.segmentationFrames.count)")
        }
    }
    
    func getFrames() -> [CIImage] {
        var frames: [CIImage] = []
        processingQueue.sync {
            frames = Array(self.segmentationFrames)
        }
        return frames
    }
}
