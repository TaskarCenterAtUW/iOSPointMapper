//
//  AnnotationAPITransmissionController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

import SwiftUI
import CoreLocation

// TODO: AnnotatedDetectedObject was very quickly changed from struct to class
// Hence we need to test more thoroughly if this breaks anything.
class AnnotatedDetectedObject {
    var id: UUID = UUID()
    var object: DetectedObject?
    var classLabel: UInt8
    var depthValue: Float
    var isAll: Bool = false
    var label: String?
    
    var selectedOption: AnnotationOption = .individualOption(.agree)
    
    init(object: DetectedObject?, classLabel: UInt8, depthValue: Float, isAll: Bool = false,
         label: String? = AnnotationViewConstants.Texts.selectAllLabelText) {
        self.object = object
        self.classLabel = classLabel
        self.depthValue = depthValue
        self.isAll = isAll
        self.label = label
        
        self.selectedOption = isAll ? .classOption(.agree) : .individualOption(.agree)
    }
}

// Extension for uploading the annotated changes to the server
extension AnnotationView {
    func uploadAnnotatedChanges(annotatedDetectedObjects: [AnnotatedDetectedObject], segmentationClass: SegmentationClass) {
        // TODO: It would be more efficient to do the following filtering before the uploadAnnotatedChanges function is called.
        // Before the post-processing is done, such as the depth being calculated for each object.
        let allObjects = annotatedDetectedObjects.filter { $0.isAll }
        // If the "all" object has selected option as .discard, we discard all objects.
        if let allObject = allObjects.first, allObject.selectedOption == .classOption(.discard) {
            print("Discarding all objects")
            return
        }
        let uploadObjects = annotatedDetectedObjects.filter { annotatedDetectedObject in
            // We only upload objects that are not "all" and have a valid depth value.
            // Also, if the selected option is .discard, we do not upload the object.
            return (annotatedDetectedObject.object != nil &&
                    !annotatedDetectedObject.isAll &&
                    annotatedDetectedObject.selectedOption != .classOption(.discard) &&
                    annotatedDetectedObject.selectedOption != .individualOption(.discard))
        }
        guard !uploadObjects.isEmpty else {
            print("No objects to upload")
            return
        }
        
        // We assume that every object is of the same class.
        let isWay = segmentationClass.isWay
        if isWay {
            // We upload all the nodes along with the way.
            uploadWay(annotatedDetectedObject: uploadObjects[0], segmentationClass: segmentationClass)
        } else {
            // We upload all the nodes.
            uploadNodes(annotatedDetectedObjects: uploadObjects, segmentationClass: segmentationClass)
        }
    }
    
    func uploadWay(annotatedDetectedObject: AnnotatedDetectedObject, segmentationClass: SegmentationClass) {
        var tempId = -1
        var nodeData = getNodeDataFromAnnotatedObject(
            annotatedDetectedObject: annotatedDetectedObject, id: tempId, isWay: true, segmentationClass: segmentationClass)
        tempId -= 1
        
        var wayDataOperations: [ChangesetDiffOperation] = []
        if let nodeData = nodeData {
            wayDataOperations.append(ChangesetDiffOperation.create(nodeData))
        }
        
        var wayData = self.sharedImageData.wayGeometries[segmentationClass.labelValue]?.last
        var wayWidth = self.sharedImageData.wayWidthHistory[segmentationClass.labelValue]?.last
        // If the wayData is already present, we will modify the existing wayData instead of creating a new one.
        if wayData != nil, wayData?.id != "-1" && wayData?.id != "" {
//            var wayData = wayData!
            if let nodeData = nodeData {
                wayData?.nodeRefs.append(nodeData.id)
                
            }
            wayDataOperations.append(ChangesetDiffOperation.modify(wayData!))
            wayWidth?.widths.append(annotatedDetectedObject.object?.finalWidth ?? annotatedDetectedObject.object?.calculatedWidth ?? 0.0)
            self.sharedImageData.wayWidthHistory[segmentationClass.labelValue]?.removeLast()
        } else {
            let className = segmentationClass.name
            let wayTags: [String: String] = [APIConstants.TagKeys.classKey: className]
            
            var nodeRefs: [String] = []
            if let nodeData = nodeData {
                nodeRefs.append(nodeData.id)
            }
            wayData = WayData(id: String(tempId), tags: wayTags, nodeRefs: nodeRefs)
            wayDataOperations.append(ChangesetDiffOperation.create(wayData!))
            
            // Create wayWidth and add to wayWidthHistory
            wayWidth = WayWidth(id: String(tempId), classLabel: segmentationClass.labelValue,
                widths: [annotatedDetectedObject.object?.finalWidth ?? annotatedDetectedObject.object?.calculatedWidth ?? 0.0])
        }
        if let wayWidth = wayWidth {
            self.sharedImageData.wayWidthHistory[segmentationClass.labelValue, default: []].append(wayWidth)
        }
        
        ChangesetService.shared.performUpload(operations: wayDataOperations) { result in
            switch result {
            case .success(let response):
                print("Changes uploaded successfully.")
                DispatchQueue.main.async {
                    sharedImageData.isUploadReady = true
                    
                    guard let nodeMap = response.nodes else {
                        print("Node map is nil")
                        return
                    }
                    let oldNodeId = nodeData?.id
                    for nodeId in nodeMap.keys {
                        guard nodeData?.id == nodeId else { continue }
                        guard let newId = nodeMap[nodeId]?[APIConstants.AttributeKeys.newId],
                                let newVersion = nodeMap[nodeId]?[APIConstants.AttributeKeys.newVersion]
                        else { continue }
                        nodeData?.id = newId
                        nodeData?.version = newVersion
                        sharedImageData.appendNodeGeometry(nodeData: nodeData!,
                                                           classLabel: segmentationClass.labelValue)
                    }
                    
                    // Update the way data with the new id and version
                    guard let wayMap = response.ways else {
                        print("Way map is nil")
                        return
                    }
                    for wayId in wayMap.keys {
                        guard wayData?.id == wayId else { continue }
                        guard let newId = wayMap[wayId]?[APIConstants.AttributeKeys.newId],
                                let newVersion = wayMap[wayId]?[APIConstants.AttributeKeys.newVersion]
                        else { continue }
                        wayData?.id = newId
                        wayData?.version = newVersion
                        // Update the wayData's nodeRefs with the new node id
                        if let nodeData = nodeData,
                            let oldNodeId = oldNodeId,
                           let oldNodeIdIndex = wayData?.nodeRefs.firstIndex(of: oldNodeId) {
                            wayData?.nodeRefs[oldNodeIdIndex] = nodeData.id
                        }
                        sharedImageData.wayGeometries[segmentationClass.labelValue]?.removeLast()
                        sharedImageData.appendWayGeometry(wayData: wayData!,
                                                          classLabel: segmentationClass.labelValue)
                    }
                }
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    func uploadNodes(annotatedDetectedObjects: [AnnotatedDetectedObject], segmentationClass: SegmentationClass) {
        var tempId = -1
        let nodeDataObjects: [NodeData?] = annotatedDetectedObjects.map { object in
            let nodeData = getNodeDataFromAnnotatedObject(
                annotatedDetectedObject: object, id: tempId, isWay: false, segmentationClass: segmentationClass)
            tempId -= 1
            return nodeData
        }
        let nodeDataObjectsToUpload: [NodeData] = nodeDataObjects.compactMap { $0 }
        let nodeDataObjectMap: [String: NodeData] = nodeDataObjectsToUpload.reduce(into: [:]) { $0[$1.id] = $1 }
        
        let nodeDataOperations: [ChangesetDiffOperation] = nodeDataObjectsToUpload.map { nodeData in
            return ChangesetDiffOperation.create(nodeData)
        }
        
        ChangesetService.shared.performUpload(operations: nodeDataOperations) { result in
            switch result {
            case .success(let response):
                print("Changes uploaded successfully.")
                DispatchQueue.main.async {
                    sharedImageData.isUploadReady = true
                    
                    // Updata every node data with the new id and version and append to sharedImageData
                    guard let nodeMap = response.nodes else {
                        print("Node map is nil")
                        return
                    }
                    for nodeId in nodeMap.keys {
                        guard var nodeData = nodeDataObjectMap[nodeId] else { continue }
                        guard let newId = nodeMap[nodeId]?[APIConstants.AttributeKeys.newId],
                                let newVersion = nodeMap[nodeId]?[APIConstants.AttributeKeys.newVersion]
                        else { continue }
                        nodeData.id = newId
                        nodeData.version = newVersion
                        sharedImageData.appendNodeGeometry(nodeData: nodeData,
                                                           classLabel: segmentationClass.labelValue)
                    }
                }
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    func uploadNodeWithoutDepth(location: (latitude: CLLocationDegrees, longitude: CLLocationDegrees)?,
                                segmentationClass: SegmentationClass) {
        guard let nodeLatitude = location?.latitude,
              let nodeLongitude = location?.longitude
        else { return }
        
        let tags: [String: String] = [APIConstants.TagKeys.classKey: segmentationClass.name]
        
        var nodeData = NodeData(latitude: nodeLatitude, longitude: nodeLongitude, tags: tags)
        let nodeDataOperations: [ChangesetDiffOperation] = [ChangesetDiffOperation.create(nodeData)]
        
        ChangesetService.shared.performUpload(operations: nodeDataOperations) { result in
            switch result {
            case .success(let response):
                print("Changes uploaded successfully.")
                DispatchQueue.main.async {
                    sharedImageData.isUploadReady = true
                    
                    guard let nodeMap = response.nodes else {
                        print("Node map is nil")
                        return
                    }
                    for nodeId in nodeMap.keys {
                        guard nodeData.id == nodeId else { continue }
                        guard let newId = nodeMap[nodeId]?[APIConstants.AttributeKeys.newId],
                                let newVersion = nodeMap[nodeId]?[APIConstants.AttributeKeys.newVersion]
                        else { continue }
                        nodeData.id = newId
                        nodeData.version = newVersion
                        sharedImageData.appendNodeGeometry(nodeData: nodeData,
                                                           classLabel: segmentationClass.labelValue)
                    }
                }
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    /**
        Get the NodeData from the AnnotatedDetectedObject.
        Calculates the location of the object based on the depth value and device location.
        Calculates other attributes such as width for ways.
     */
    func getNodeDataFromAnnotatedObject(
        annotatedDetectedObject: AnnotatedDetectedObject,
        id: Int, isWay: Bool = false, segmentationClass: SegmentationClass
    ) -> NodeData? {
        let centroid = annotatedDetectedObject.object?.centroid
        let pointWithDepth: SIMD3<Float> = SIMD3<Float>(
            x: Float(centroid?.x ?? 0.0),
            y: Float(centroid?.y ?? 0.0),
            z: annotatedDetectedObject.depthValue
        )
        let imageSize = annotationImageManager.segmentationUIImage?.size ?? CGSize.zero
//        let location = objectLocation.getCalcLocation(depthValue: annotatedDetectedObject.depthValue)
        let location = objectLocation.getCalcLocation(
            pointWithDepth: pointWithDepth, imageSize: imageSize,
            cameraTransform: self.sharedImageData.cameraTransform,
            cameraIntrinsics: self.sharedImageData.cameraIntrinsics,
            deviceOrientation: self.sharedImageData.deviceOrientation ?? .landscapeLeft,
            originalImageSize: self.sharedImageData.originalImageSize ?? imageSize
        )
        self.currentDepthValues = self.currentDepthValues + "\nObject: \(location?.latitude ?? 0.0),\(location?.longitude ?? 0.0),\(annotatedDetectedObject.depthValue)"
        guard let nodeLatitude = location?.latitude,
              let nodeLongitude = location?.longitude
        else { return nil }
        
        let className = segmentationClass.name
        var tags: [String: String] = [APIConstants.TagKeys.classKey: className]
        tags[APIConstants.TagKeys.depthKey] = String(format: "%.4f", annotatedDetectedObject.depthValue)
        
        if isWay {
            // MARK: Width Field Demo: Use the calculated or validated width for the way bounds if present
            var width: Float = 0.0
            if annotatedDetectedObject.object?.calculatedWidth != nil {
                width = annotatedDetectedObject.object?.finalWidth ?? annotatedDetectedObject.object?.calculatedWidth ?? 0
                tags[APIConstants.TagKeys.calculatedWidthKey] = String(format: "%.4f", annotatedDetectedObject.object?.calculatedWidth ?? 0)
            } else {
                let wayBoundsWithDepth = getWayBoundsWithDepth(wayBounds: annotatedDetectedObject.object?.wayBounds ?? [])
                if let wayBoundsWithDepth = wayBoundsWithDepth {
                    width = objectLocation.getWayWidth(
                        wayBoundsWithDepth: wayBoundsWithDepth,
                        imageSize: annotationImageManager.segmentationUIImage?.size ?? CGSize.zero,
                        cameraTransform: self.sharedImageData.cameraTransform,
                        cameraIntrinsics: self.sharedImageData.cameraIntrinsics,
                        deviceOrientation: self.sharedImageData.deviceOrientation ?? .landscapeLeft,
                        originalImageSize: self.sharedImageData.originalImageSize ?? imageSize
                    )
                }
            }
            tags[APIConstants.TagKeys.widthKey] = String(format: "%.4f", width)
            let breakageStatus: Bool = annotatedDetectedObject.object?.finalBreakage ??
            annotatedDetectedObject.object?.calculatedBreakage ?? false
            tags[APIConstants.TagKeys.breakageKey] = String(breakageStatus)
        }
        print("Tags for node: \(tags)")
        
        let nodeData = NodeData(id: String(id),
                                latitude: nodeLatitude, longitude: nodeLongitude, tags: tags)
        return nodeData
    }
    
    /**
     Get the depth values for each point in the way bounds.
     */
    func getWayBoundsWithDepth(wayBounds: [SIMD2<Float>]) -> [SIMD3<Float>]? {
        guard wayBounds.count == 4 else {
            print("Invalid way bounds")
            return nil
        }
        let lowerLeft = wayBounds[0]
        let upperLeft = wayBounds[1]
        let upperRight = wayBounds[2]
        let lowerRight = wayBounds[3]
        
        let wayPoints: [SIMD2<Float>] = [
            lowerLeft, upperLeft, upperRight, lowerRight
        ]
        // Since the way bounds are in normalized coordinates, we need to convert them to CGPoints
        guard let depthMapProcessor = self.depthMapProcessor else {
            print("Depth map processor is nil")
            return nil
        }
        let depthImageDimensions = depthMapProcessor.getDepthImageDimensions()
        let wayCGPoints: [CGPoint] = wayPoints.map {
            CGPoint(
                x: CGFloat($0.x) * CGFloat(depthImageDimensions.width),
                y: CGFloat($0.y) * CGFloat(depthImageDimensions.height)
            )
        }
        
        var depthValues: [Float]?
        if let segmentationLabelImage = self.annotationImageManager.annotatedSegmentationLabelImage,
           segmentationLabelImage.pixelBuffer != nil,
           let depthImage = self.sharedImageData.depthImage {
            depthValues = self.depthMapProcessor?.getDepthValuesInRadius(
                segmentationLabelImage: segmentationLabelImage,
                at: wayCGPoints, depthRadius: 3, depthImage: depthImage,
                classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[self.index]])
        } else {
            depthValues = self.depthMapProcessor?.getValues(at: wayCGPoints)
        }
            
        guard let depthValues = depthValues else {
            print("Failed to get depth values for way bounds")
            return wayPoints.map { SIMD3<Float>(x: $0.x, y: $0.y, z: 0) }
        }
        guard depthValues.count == wayBounds.count else {
            print("Depth values count does not match way bounds count")
            return wayPoints.map { SIMD3<Float>(x: $0.x, y: $0.y, z: 0) }
        }
        let wayBoundsWithDepth: [SIMD3<Float>] = wayPoints.enumerated().map { index, point in
            return SIMD3<Float>(x: point.x, y: point.y, z: depthValues[index])
        }
        return wayBoundsWithDepth
    }
}
