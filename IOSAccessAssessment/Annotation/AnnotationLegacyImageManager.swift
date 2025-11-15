//
//  AnnotationImageManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

import Foundation
import SwiftUI
import Combine
import simd

typealias AnnotationCameraUIImageOutput = (cgImage: CGImage, uiImage: UIImage)
typealias AnnotationSegmentationUIImageOutput = (ciImage: CIImage, uiImage: UIImage)
typealias AnnotationObjectsUIImageOutput = (annotatedDetectedObjects: [AnnotatedDetectedObject], selectedObjectId: UUID, uiImage: UIImage)

/**
 The AnnotationImageManager class is responsible for managing the images used in the annotation process.
 It handles updates to the camera image, segmentation label image, and detected objects image.
 */
class AnnotationLegacyImageManager: ObservableObject {
    @Published var cameraUIImage: UIImage? = nil
    @Published var segmentationUIImage: UIImage? = nil
    @Published var objectsUIImage: UIImage? = nil
    
    @State private var transformedLabelImages: [CIImage]? = nil
    
    @Published var annotatedSegmentationLabelImage: CIImage? = nil
    @Published var annotatedDetectedObjects: [AnnotatedDetectedObject]? = nil
    
    @Published var selectedObjectId: UUID? = nil
    @Published var selectedObjectWidth: Float? = nil // MARK: Width Field Demo: Temporary property to hold the selected object width
    @Published var selectedObjectBreakage: Bool? = nil // MARK: Breakage Field Demo: Temporary property to hold the selected object breakage status
    @Published var selectedObjectSlope: Float? = nil // MARK: Slope Field Demo: Temporary property to hold the selected object slope value
    @Published var selectedObjectCrossSlope: Float? = nil // MARK: Cross Slope Field Demo: Temporary property to hold the selected object cross slope value
    
    // Helpers
    private let annotationCIContext = CIContext()
    private let annotationSegmentationPipeline = AnnotationSegmentationPipeline()
    // MARK: Temporarily commented out to setup refactoring
//    private let grayscaleToColorMasker = GrayscaleToColorFilter()
    
    func isImageInvalid() -> Bool {
        if (self.cameraUIImage == nil || self.segmentationUIImage == nil || self.objectsUIImage == nil) {
            return true
        }
        return false
    }
    
    func update(cameraImage: CIImage, segmentationLabelImage: CIImage, imageHistory: [ImageData],
                accessibilityFeatureClass: AccessibilityFeatureClass) {
        // TODO: Handle the case of transformedLabelImages being nil
        let transformedLabelImages = transformImageHistoryForUnionOfMasks(imageDataHistory: imageHistory)
        
        let cameraUIImageOutput = getCameraUIImage(cameraImage: cameraImage)
        let segmentationUIImageOutput = getSegmentationUIImage(
            segmentationLabelImage: segmentationLabelImage, accessibilityFeatureClass: accessibilityFeatureClass)
        
        let objectsInputLabelImage = segmentationUIImageOutput.ciImage
        let objectsUIImageOutput = getObjectsUIImage(
            inputLabelImage: objectsInputLabelImage, accessibilityFeatureClass: accessibilityFeatureClass)
        
        // Start updating the state
        objectWillChange.send()
        self.transformedLabelImages = transformedLabelImages
        self.cameraUIImage = cameraUIImageOutput.uiImage
        self.annotatedSegmentationLabelImage = segmentationUIImageOutput.ciImage
        self.segmentationUIImage = segmentationUIImageOutput.uiImage
        self.annotatedDetectedObjects = objectsUIImageOutput.annotatedDetectedObjects
        self.selectedObjectId = objectsUIImageOutput.selectedObjectId
        self.objectsUIImage = objectsUIImageOutput.uiImage
    }
    
    private func transformImageHistoryForUnionOfMasks(imageDataHistory: [ImageData]) -> [CIImage]? {
        do {
            let transformedLabelImages = try self.annotationSegmentationPipeline.processTransformationsRequest(
                imageDataHistory: imageDataHistory)
            try self.annotationSegmentationPipeline.setupUnionOfMasksRequest(segmentationLabelImages: transformedLabelImages)
            return transformedLabelImages
        } catch {
            print("Error processing transformations request: \(error)")
        }
        return nil
    }
    
    private func getCameraUIImage(cameraImage: CIImage) -> AnnotationCameraUIImageOutput {
        let cameraCGImage = annotationCIContext.createCGImage(
            cameraImage, from: cameraImage.extent)!
        let cameraUIImage = UIImage(cgImage: cameraCGImage, scale: 1.0, orientation: .up)
        return (cgImage: cameraCGImage,
                uiImage: cameraUIImage)
    }
    
    // Perform the union of masks on the label image history for the given segmentation class.
    // Save the resultant image to the segmentedLabelImage property.
    private func getSegmentationUIImage(segmentationLabelImage: CIImage, accessibilityFeatureClass: AccessibilityFeatureClass)
    -> AnnotationSegmentationUIImageOutput {
        var inputLabelImage = segmentationLabelImage
        do {
            inputLabelImage = try self.annotationSegmentationPipeline.processUnionOfMasksRequest(
                targetValue: accessibilityFeatureClass.labelValue,
                bounds: accessibilityFeatureClass.bounds,
                unionOfMasksPolicy: accessibilityFeatureClass.unionOfMasksPolicy
            )
        } catch {
            print("Error processing union of masks request: \(error)")
        }
//        self.annotatedSegmentationLabelImage = inputLabelImage
//        let segmentationColorImage = self.grayscaleToColorMasker.apply(
//            to: inputLabelImage, grayscaleValues: [segmentationClass.grayscaleValue], colorValues: [segmentationClass.color])
        
        let segmentationUIImage = UIImage(ciImage: segmentationLabelImage, scale: 1.0, orientation: .up)
        // Check if inputLabelImage is backed by a CVPixelBuffer
        if inputLabelImage.extent.width == 0 || inputLabelImage.extent.height == 0 {
            print("Warning: inputLabelImage has zero width or height.")
        }
//        print("inputLabelImage pixelBuffer nil?: \(inputLabelImage.pixelBuffer == nil)")
        return (ciImage: inputLabelImage,
                uiImage: segmentationUIImage)
    }
    
    private func getObjectsUIImage(inputLabelImage: CIImage, accessibilityFeatureClass: AccessibilityFeatureClass)
    -> AnnotationObjectsUIImageOutput {
        var inputDetectedObjects: [DetectedObject] = []
        
        // Get the detected objects from the resultant union image.
        do {
            inputDetectedObjects = try self.annotationSegmentationPipeline.processContourRequest(
                from: inputLabelImage,
                targetValue: accessibilityFeatureClass.labelValue,
                isWay: accessibilityFeatureClass.isWay,
                bounds: accessibilityFeatureClass.bounds
            )
        } catch {
            print("Error processing contour request: \(error)")
        }
        var annotatedDetectedObjects = inputDetectedObjects.enumerated().map({ objectIndex, object in
            AnnotatedDetectedObject(object: object, classLabel: object.classLabel, depthValue: 0.0, isAll: false,
                                    label: accessibilityFeatureClass.name + ": " + String(objectIndex))
        })
        // Add the "all" object to the beginning of the list
        annotatedDetectedObjects.insert(
            AnnotatedDetectedObject(object: nil, classLabel: accessibilityFeatureClass.labelValue,
                                    depthValue: 0.0, isAll: true, label: AnnotationLegacyViewConstants.Texts.selectAllLabelText),
            at: 0
        )
//        self.annotatedDetectedObjects = annotatedDetectedObjects
        let selectedObjectId = annotatedDetectedObjects[0].id
        let objectsUIImage = UIImage(
            cgImage: ContourObjectRasterizer.rasterizeContourObjects(
                objects: inputDetectedObjects,
                size: Constants.SelectedAccessibilityFeatureConfig.inputSize,
                polygonConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
                wayBoundsConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                centroidConfig: RasterizeConfig(draw: true, color: nil, width: 5)
            )!,
            scale: 1.0, orientation: .up)
        
        return (annotatedDetectedObjects: annotatedDetectedObjects,
                selectedObjectId: selectedObjectId,
                uiImage: objectsUIImage)
    }
    
    func updateObjectSelection(previousSelectedObjectId: UUID?, selectedObjectId: UUID) {
        guard let baseImage = self.objectsUIImage?.cgImage else {
            print("Base image is nil")
            return
        }
        
        var oldObjects: [DetectedObject] = []
        var newObjects: [DetectedObject] = []
        var newImage: CGImage?
        
        if let previousSelectedObjectId = previousSelectedObjectId {
            for object in self.annotatedDetectedObjects ?? [] {
                if object.id == previousSelectedObjectId {
                    if object.object != nil { oldObjects.append(object.object!) }
                    break
                }
            }
        }
        newImage = ContourObjectRasterizer.updateRasterizedImage(
            baseImage: baseImage, objects: oldObjects, size: Constants.SelectedAccessibilityFeatureConfig.inputSize,
            polygonConfig: RasterizeConfig(draw: true, color: nil, width: 2),
            boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
            wayBoundsConfig: RasterizeConfig(draw: true, color: nil, width: 2),
            centroidConfig: RasterizeConfig(draw: true, color: nil, width: 5)
        )
        if newImage == nil { print("Failed to update rasterized image") }
        
        for object in self.annotatedDetectedObjects ?? [] {
            if object.id == selectedObjectId {
                if object.object != nil { newObjects.append(object.object!) }
                break
            }
        }
        newImage = newImage ?? baseImage
        newImage = ContourObjectRasterizer.updateRasterizedImage(
            baseImage: newImage!, objects: newObjects, size: Constants.SelectedAccessibilityFeatureConfig.inputSize,
            polygonConfig: RasterizeConfig(draw: true, color: .white, width: 2),
            boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
            wayBoundsConfig: RasterizeConfig(draw: true, color: .white, width: 2),
            centroidConfig: RasterizeConfig(draw: true, color: .white, width: 5)
        )        
        
        if let newImage = newImage {
            self.objectsUIImage = UIImage(cgImage: newImage, scale: 1.0, orientation: .up)
        } else { print("Failed to update rasterized image") }
    }
}
