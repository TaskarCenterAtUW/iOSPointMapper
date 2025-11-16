//
//  AnnotationImageManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/15/25.
//
import SwiftUI

enum AnnotatiomImageManagerError: Error, LocalizedError {
    case notConfigured
    case imageResultCacheFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AnnotationImageManager is not configured."
        case .imageResultCacheFailed:
            return "Failed to retrieve the cached annotation image results."
        }
    }
}

struct AnnotationImageResults {
    let cameraImage: CIImage
    
    let segmentationLabelImage: CIImage
    
    var cameraOutputImage: CIImage? = nil
    var overlayedOutputImage: CIImage? = nil
}

final class AnnotationImageManager: NSObject, ObservableObject, AnnotationImageProcessingDelegate {
    var selectedClasses: [AccessibilityFeatureClass] = []
    
    weak var outputConsumer: AnnotationImageProcessingOutputConsumer? = nil
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    let cIContext = CIContext(options: nil)
    
    @Published var isConfigured: Bool = false
    
    // Latest processed results
    var annotationImageResults: AnnotationImageResults?
    
    func configure(
        selectedClasses: [AccessibilityFeatureClass]
    ) {
        self.selectedClasses = selectedClasses
        self.isConfigured = true
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        self.interfaceOrientation = orientation
    }
    
    func update(
        cameraImage: CIImage,
        segmentationLabelImage: CIImage,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws {
        guard isConfigured else {
            throw AnnotatiomImageManagerError.notConfigured
        }
    }
    
    func update(
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws {
        guard isConfigured else {
            throw AnnotatiomImageManagerError.notConfigured
        }
        guard let cameraImage = self.annotationImageResults?.cameraImage,
              let segmentationLabelImage = self.annotationImageResults?.segmentationLabelImage else {
            throw AnnotatiomImageManagerError.imageResultCacheFailed
        }
    }
}
