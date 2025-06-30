//
//  SharedImageData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//
import SwiftUI
import DequeModule
import simd

// TODO: DetectedObject was very quickly changed from struct to class
// Hence we need to test more thoroughly if this breaks anything.
class DetectedObject {
    let classLabel: UInt8
    
    var centroid: CGPoint
    var boundingBox: CGRect // Bounding box in the original image coordinates. In normalized coordinates.
    var normalizedPoints: [SIMD2<Float>]
    var area: Float
    var perimeter: Float
    
    var isCurrent: Bool // Indicates if the object is from the current frame or a previous frame
    var wayBounds: [SIMD2<Float>]? // Special property for way-type objects. In normalized coordinates.
    
    // MARK: Width Field Demo: Temporary properties for object width if it is a way-type object
    var calculatedWidth: Float? // Width of the object in meters
    var finalWidth: Float? // Final width of the object in meters after validation
    
    // MARK: Breakage Field Demo: Temporary properties for object breakage if it is a way-type object
    var calculatedBreakage: Bool? // Indicates if the object is broken or not
    var finalBreakage: Bool? // Final indication of breakage after validation
    
    init(classLabel: UInt8, centroid: CGPoint, boundingBox: CGRect, normalizedPoints: [SIMD2<Float>], area: Float, perimeter: Float, isCurrent: Bool, wayBounds: [SIMD2<Float>]? = nil) {
        self.classLabel = classLabel
        self.centroid = centroid
        self.boundingBox = boundingBox
        self.normalizedPoints = normalizedPoints
        self.area = area
        self.perimeter = perimeter
        self.isCurrent = isCurrent
        self.wayBounds = wayBounds
    }
}

class ImageData {
    var cameraImage: CIImage?
    var depthImage: CIImage?
    
    var segmentationLabelImage: CIImage?
    var segmentedIndices: [Int]?
    var detectedObjectMap: [UUID: DetectedObject]?
    
    // TODO: Create a separate class for AR-related ImageData
    // The separate class would give preference to AR-related transforms over image transforms (such as homography)
    var cameraTransform: simd_float4x4
    var cameraIntrinsics: simd_float3x3
    
    // Transformation matrix from the current frame to the next frame
    var transformMatrixToNextFrame: simd_float3x3?
    // Transformation matrix from the current frame to the previous frame
    var transformMatrixToPreviousFrame: simd_float3x3?
    
    var deviceOrientation: UIDeviceOrientation? // Orientation of the device at the time of capture
    var originalImageSize: CGSize? // Size of the original image at the time of capture
    
    init(cameraImage: CIImage? = nil, depthImage: CIImage? = nil,
         segmentationLabelImage: CIImage? = nil, segmentedIndices: [Int]? = nil,
         detectedObjectMap: [UUID: DetectedObject]? = nil,
         cameraTransform: simd_float4x4 = matrix_identity_float4x4, cameraIntrinsics: simd_float3x3 = matrix_identity_float3x3,
         transformMatrixToNextFrame: simd_float3x3? = nil, transformMatrixToPreviousFrame: simd_float3x3? = nil,
         deviceOrientation: UIDeviceOrientation? = nil, originalImageSize: CGSize? = nil) {
        self.cameraImage = cameraImage
        self.depthImage = depthImage
        self.segmentationLabelImage = segmentationLabelImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjectMap = detectedObjectMap
        self.cameraTransform = cameraTransform
        self.cameraIntrinsics = cameraIntrinsics
        self.transformMatrixToNextFrame = transformMatrixToNextFrame
        self.transformMatrixToPreviousFrame = transformMatrixToPreviousFrame
        self.deviceOrientation = deviceOrientation
        self.originalImageSize = originalImageSize
    }
}

struct WayWidth {
    var id: String
    var classLabel: UInt8
    var widths: [Float] // Widths of the way in meters
}

/**
    SharedImageData is a "singleton" class that holds the camera image, depth image, segmentation label image,
    segmented indices, detected objects, and the history of images.
 
    It is used to share data between different parts of the app, such as the camera view and the segmentation pipeline.
 
    Currently, while it is an ObservableObject, it is not used as a state object in the app. It is merely used as a global data store.
 */
class SharedImageData: ObservableObject {
    @Published var isUploadReady: Bool = false
    var isLidarAvailable: Bool = ARCameraUtils.checkDepthSupport()
    
    // TODO: Replace the following properties with a single ImageData object.
    var cameraImage: CIImage?
    var depthImage: CIImage?
    // Overall segmentation image with all classes (labels)
    var segmentationLabelImage: CIImage?
    // Indices of all the classes that were detected in the segmentation image
    var segmentedIndices: [Int] = []
    var detectedObjectMap: [UUID: DetectedObject] = [:]
    // Camera transform matrix and intrinsics
    var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    var cameraIntrinsics: simd_float3x3 = matrix_identity_float3x3
    // Orientation and original image size
    var deviceOrientation: UIDeviceOrientation? = nil
    var originalImageSize: CGSize? = nil
    
    // Transformation matrices for the current frame
    var transformMatrixToPreviousFrame: simd_float3x3? = nil
    
    var history: Deque<ImageData> = []
    private let historyQueue = DispatchQueue(label: "com.example.sharedimagedata.history.queue", qos: .utility)
    var historyMaxCapacity: Int = 5
        
    var segmentationFrames: Deque<CIImage> = []
    private let processingQueue = DispatchQueue(label: "com.example.sharedimagedata.queue", qos: .utility)
    var maxCapacity: Int
    var thresholdRatio: Float = 0.7
    
    // Geometry data by class label
    var nodeGeometries: [UInt8: [NodeData]] = [:]
    var wayGeometries: [UInt8: [WayData]] = [:]
    // NOTE: Tempoary width history
    var wayWidthHistory: [UInt8: [WayWidth]] = [:]
    
    init(maxCapacity: Int = 100, thresholdRatio: Float = 0.7, historyMaxCapacity: Int = 5) {
        self.maxCapacity = maxCapacity
        self.thresholdRatio = thresholdRatio
        self.historyMaxCapacity = historyMaxCapacity
    }
    
    func refreshData() {
        self.isUploadReady = false
        
        self.cameraImage = nil
        
        // TODO: Sometimes it is possible for the following to return false even when the device supports LiDAR.
        // Should inform the user about this if it happens.
        self.isLidarAvailable = ARCameraUtils.checkDepthSupport()
        self.depthImage = nil
        
        self.segmentationLabelImage = nil
        self.segmentedIndices = []
        self.detectedObjectMap = [:]
        self.transformMatrixToPreviousFrame = nil
        
        self.history.removeAll()
        self.segmentationFrames.removeAll()
        
        self.nodeGeometries.removeAll()
        self.wayGeometries.removeAll()
        self.wayWidthHistory.removeAll()
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
    
    func appendNodeGeometry(nodeData: NodeData, classLabel: UInt8) {
        self.nodeGeometries[classLabel, default: []].append(nodeData)
    }
    
    func appendWayGeometry(wayData: WayData, classLabel: UInt8) {
        self.wayGeometries[classLabel, default: []].append(wayData)
    }
    
    func appendWayWidthToWayWidthHistory(wayWidth: WayWidth, classLabel: UInt8) {
        self.wayWidthHistory[classLabel, default: []].append(wayWidth)
    }
    
    // TODO: By default, we append the node of a class to the last wayData of the same class.
    // However, currently, there will never be more than one wayData of a class in one changeset.
    // Check if we should add functionality to support multiple wayData of the same class in one changeset
    func appendNodeToWayGeometry(nodeData: NodeData, classLabel: UInt8) {
        // If the class is of type way, only then can we append to the wayGeometries
        let isWay = Constants.ClassConstants.classes.filter { $0.labelValue == classLabel }.first?.isWay ?? false
        guard isWay else {
            print("Class \(classLabel) is not a way class")
            return
        }
        guard let wayData = self.wayGeometries[classLabel]?.last else {
            print("No way data found for class \(classLabel)")
            return
        }
        // Append the nodeData to the wayData
        var updatedWayData = wayData
        updatedWayData.nodeRefs.append(nodeData.id)
        self.wayGeometries[classLabel]?.removeLast()
        self.wayGeometries[classLabel]?.append(updatedWayData)
    }
    
    func appendWidthToWayWidth(width: Float, classLabel: UInt8) {
        let isWay = Constants.ClassConstants.classes.filter { $0.labelValue == classLabel }.first?.isWay ?? false
        guard isWay else {
            print("Class \(classLabel) is not a way class")
            return
        }
        guard let wayWidths = self.wayWidthHistory[classLabel]?.last else {
            print("No way width history found for class \(classLabel)")
            return
        }
        // Append the wayWidth to the wayWidths
        var updatedWayWidths = wayWidths
        updatedWayWidths.widths.append(width)
        self.wayWidthHistory[classLabel]?.removeLast()
        self.wayWidthHistory[classLabel]?.append(updatedWayWidths)
    }
}
