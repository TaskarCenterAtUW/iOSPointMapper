//
//  SegmentationMeshPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 10/28/25.
//

import SwiftUI
import ARKit
import RealityKit
import simd

enum SegmentationMeshPipelineError: Error, LocalizedError {
}

struct SegmentationMeshPipelineResults {
    var modelEntities: [UUID: ModelEntity] = [:]
    var assignedColors: [UUID: UIColor] = [:]
}

/**
 A class to generate 3D mesh models from segmentation data to help integrate them into an AR scene.
 */
final class SegmentationMeshPipeline: ObservableObject {
    private var isProcessing = false
    private var currentTask: Task<SegmentationMeshPipelineResults, Error>?
    
    private var selectionClasses: [Int] = []
    private var selectionClassLabels: [UInt8] = []
    private var selectionClassGrayscaleValues: [Float] = []
    private var selectionClassColors: [CIColor] = []
    
    func reset() {
        self.isProcessing = false
        self.setSelectionClasses([])
    }
    
    func setSelectionClasses(_ selectionClasses: [Int]) {
        self.selectionClasses = selectionClasses
        self.selectionClassLabels = selectionClasses.map { Constants.SelectedSegmentationConfig.labels[$0] }
        self.selectionClassGrayscaleValues = selectionClasses.map { Constants.SelectedSegmentationConfig.grayscaleValues[$0] }
        self.selectionClassColors = selectionClasses.map { Constants.SelectedSegmentationConfig.colors[$0] }
    }
}
