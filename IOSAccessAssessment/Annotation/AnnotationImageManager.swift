//
//  AnnotationImageManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/15/25.
//
import SwiftUI

final class AnnotationImageManager: NSObject, ObservableObject, AnnotationImageProcessingDelegate {
    var selectedClasses: [AccessibilityFeatureClass] = []
    
    weak var outputConsumer: AnnotationImageProcessingOutputConsumer? = nil
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    let cIContext = CIContext(options: nil)
    
    @Published var isConfigured: Bool = false
    
    func configure(
        selectedClasses: [AccessibilityFeatureClass]
    ) {
        self.selectedClasses = selectedClasses
        self.isConfigured = true
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        self.interfaceOrientation = orientation
    }
}
