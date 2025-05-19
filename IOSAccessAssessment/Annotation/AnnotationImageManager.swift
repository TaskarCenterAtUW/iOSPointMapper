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

class AnnotationImageManager: ObservableObject {
    @Published var cameraUIImage: UIImage? = nil
    @Published var segmentationUIImage: UIImage? = nil
    @Published var objectsUIImage: UIImage? = nil
    
    @State private var transformedLabelImages: [CIImage]? = nil
    
    @Published var annotatedSegmentationLabelImage: CIImage? = nil
    @Published var annotatedDetectedObjects: [AnnotatedDetectedObject]? = nil
    
    private let annotationSegmentationPipeline = AnnotationSegmentationPipeline()
    private let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    
    func update(cameraImage: UIImage?, segmentationImage: UIImage?, objectsImage: UIImage?,
                annotatedSegmentationLabelImage: CIImage?, annotatedDetectedObjects: [AnnotatedDetectedObject]?) {
        
    }
    
    func update(currentImage: CIImage, imageHistory: [ImageData]) {
        let transformedLabelImages = transformImageHistoryForUnionOfMasks(imageDataHistory: imageHistory)
    }
    
    private func transformImageHistoryForUnionOfMasks(imageDataHistory: [ImageData]) -> [CIImage]? {
        do {
            let transformedLabelImages = try self.annotationSegmentationPipeline.processTransformationsRequest(
                imageDataHistory: imageDataHistory)
            self.annotationSegmentationPipeline.setupUnionOfMasksRequest(segmentationLabelImages: transformedLabelImages)
            return transformedLabelImages
        } catch {
            print("Error processing transformations request: \(error)")
        }
        return nil
    }
}
