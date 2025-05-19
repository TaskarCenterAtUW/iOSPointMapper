//
//  AnnotationAPITransmissionController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

import SwiftUI
import CoreLocation

struct AnnotatedDetectedObject {
    var id: UUID = UUID()
    var object: DetectedObject?
    var classLabel: UInt8
    var depthValue: Float
    var isAll: Bool = false
    var label: String?
    
    init(object: DetectedObject?, classLabel: UInt8, depthValue: Float, isAll: Bool = false,
         label: String? = AnnotationViewConstants.Texts.selectAllLabelText) {
        self.object = object
        self.classLabel = classLabel
        self.depthValue = depthValue
        self.isAll = isAll
        self.label = label
    }
}

// Extension for uploading the annotated changes to the server
extension AnnotationView {
    // TODO: Instead of passing one request for each object, we should be able to pass all the objects in one request.
    func uploadAnnotatedChanges(annotatedDetectedObjects: [AnnotatedDetectedObject], segmentationClass: SegmentationClass) {
        let uploadObjects = annotatedDetectedObjects.filter { $0.object != nil && !$0.isAll }
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
        // If the wayData is already present, we will modify the existing wayData instead of creating a new one.
        if wayData != nil, wayData?.id != "-1" && wayData?.id != "" {
//            var wayData = wayData!
            if let nodeData = nodeData {
                wayData?.nodeRefs.append(nodeData.id)
            }
            wayDataOperations.append(ChangesetDiffOperation.modify(wayData!))
        } else {
            let className = segmentationClass.name
            let wayTags: [String: String] = [APIConstants.TagKeys.classKey: className]
            
            var nodeRefs: [String] = []
            if let nodeData = nodeData {
                nodeRefs.append(nodeData.id)
            }
            wayData = WayData(id: String(tempId), tags: wayTags, nodeRefs: nodeRefs)
            wayDataOperations.append(ChangesetDiffOperation.create(wayData!))
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
    
    func getNodeDataFromAnnotatedObject(
        annotatedDetectedObject: AnnotatedDetectedObject,
        id: Int, isWay: Bool = false, segmentationClass: SegmentationClass
    ) -> NodeData? {
        let location = objectLocation.getCalcLocation(depthValue: annotatedDetectedObject.depthValue)
        guard let nodeLatitude = location?.latitude,
              let nodeLongitude = location?.longitude
        else { return nil }
        
        let className = segmentationClass.name
        var tags: [String: String] = [APIConstants.TagKeys.classKey: className]
        
        if isWay {
            let width = objectLocation.getWayWidth(wayBounds: annotatedDetectedObject.object?.wayBounds ?? [],
                                                   imageSize: annotationImageManager.segmentationUIImage?.size ?? CGSize.zero)
            tags[APIConstants.TagKeys.widthKey] = String(format: "%.4f", width)
        }
        
        let nodeData = NodeData(id: String(id),
                                latitude: nodeLatitude, longitude: nodeLongitude, tags: tags)
        return nodeData
    }
}
