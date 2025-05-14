//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI
import DequeModule
import simd

class ImageData {
    var cameraImage: CIImage?
    var depthImage: CIImage?
    
    var segmentationLabelImage: CIImage?
    var segmentedIndices: [Int]?
    var detectedObjects: [UUID: DetectedObject]?
    
    var transformMatrixToNextFrame: simd_float3x3?
    var transformMatrixToPreviousFrame: simd_float3x3?
    
    init(cameraImage: CIImage? = nil, depthImage: CIImage? = nil,
         segmentationLabelImage: CIImage? = nil, segmentedIndices: [Int]? = nil,
         detectedObjects: [UUID: DetectedObject]? = nil,
         transformMatrixToNextFrame: simd_float3x3? = nil, transformMatrixToPreviousFrame: simd_float3x3? = nil) {
        self.cameraImage = cameraImage
        self.depthImage = depthImage
        self.segmentationLabelImage = segmentationLabelImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjects = detectedObjects
        self.transformMatrixToNextFrame = transformMatrixToNextFrame
        self.transformMatrixToPreviousFrame = transformMatrixToPreviousFrame
    }
}

/**
    SharedImageData is a "singleton" class that holds the camera image, depth image, segmentation label image,
    segmented indices, detected objects, and the history of images.
 
    It is used to share data between different parts of the app, such as the camera view and the segmentation pipeline.
 
    Currently, while it is an ObservableObject, it is not used as a state object in the app. It is merely used as a global data store.
 */
class SharedImageData: ObservableObject {
    @Published var isUploadReady: Bool = false
    
    var cameraImage: CIImage?
    
    var isLidarAvailable: Bool = false
    var depthImage: CIImage?
    
    // Overall segmentation image with all classes (labels)
    var segmentationLabelImage: CIImage?
    // Indices of all the classes that were detected in the segmentation image
    var segmentedIndices: [Int] = []
    var detectedObjects: [UUID: DetectedObject] = [:]
    var transformMatrixToPreviousFrame: simd_float3x3? = nil
    
    var history: Deque<ImageData> = []
    private let historyQueue = DispatchQueue(label: "com.example.sharedimagedata.history.queue", qos: .utility)
    var historyMaxCapacity: Int = 5
        
    var segmentationFrames: Deque<CIImage> = []
    private let processingQueue = DispatchQueue(label: "com.example.sharedimagedata.queue", qos: .utility)
    var maxCapacity: Int
    var thresholdRatio: Float = 0.7
    
    // One way for each class
    var wayGeometries: [UInt8: String] = [:]
    
    init(maxCapacity: Int = 100, thresholdRatio: Float = 0.7, historyMaxCapacity: Int = 5) {
        self.maxCapacity = maxCapacity
        self.thresholdRatio = thresholdRatio
        self.historyMaxCapacity = historyMaxCapacity
    }
    
    func refreshData() {
        self.isUploadReady = false
        
        self.cameraImage = nil
        
        self.isLidarAvailable = checkLidarAvailability()
        self.depthImage = nil
        
        self.segmentationLabelImage = nil
        self.segmentedIndices = []
        self.detectedObjects = [:]
        self.transformMatrixToPreviousFrame = nil
        
        self.history.removeAll()
        self.segmentationFrames.removeAll()
        
        self.wayGeometries.removeAll()
    }
    
    func recordImageData(imageData: ImageData) {
        historyQueue.async {
            if self.history.count >= self.historyMaxCapacity {
                self.history.removeFirst()
            }
            self.history.append(imageData)
        }
    }
    
    func getPreviousImageData() -> ImageData? {
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
