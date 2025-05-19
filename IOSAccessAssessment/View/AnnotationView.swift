//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import CoreLocation

enum AnnotationViewConstants {
    enum Texts {
        static let annotationViewTitle = "Annotation View"
        
        static let selectedClassPrefixText = "Selected class: "
        static let finishText = "Finish"
        static let nextText = "Next"
        
        static let selectObjectText = "Select an object"
        static let selectAllLabelText = "Select All"
        
        static let confirmAnnotationFailedTitle = "Cannot confirm annotation"
        static let depthOrSegmentationUnavailableText = "Depth or segmentation related information is not available." +
        "\nDo you want to upload all the objects as a single point with the current location?"
        static let confirmAnnotationFailedConfirmText = "Yes"
        static let confirmAnnotationFailedCancelText = "No"
        
        static let selectCorrectAnnotationText = "Select correct annotation"
        static let doneText = "Done"
    }
    
    enum Images {
        static let checkIcon = "checkmark"
    }
}
        
        

enum AnnotationOption: String, CaseIterable {
    case agree = "I agree with this class annotation"
    case missingInstances = "Annotation is missing some instances of the class"
    case misidentified = "The class annotation is misidentified"
}

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

struct AnnotationView: View {
    var selection: [Int]
    var objectLocation: ObjectLocation
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @Environment(\.dismiss) var dismiss
    
    @State private var index = 0
    
    let options = AnnotationOption.allCases
    @State private var selectedOption: AnnotationOption? = nil
    @State private var isShowingClassSelectionModal: Bool = false
    @State private var selectedClassIndex: Int? = nil
    @State private var tempSelectedClassIndex: Int = 0
    
    @State private var cameraUIImage: UIImage? = nil
    @State private var segmentationUIImage: UIImage? = nil
    @State private var objectsUIImage: UIImage? = nil
    
    @State private var annotatedSegmentationLabelImage: CIImage? = nil
    @State private var annotatedDetectedObjects: [AnnotatedDetectedObject]? = nil
    @State private var selectedObjectId: UUID? = nil
    
    private let annotationCIContext = CIContext()
    private let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    @State private var depthMapProcessor: DepthMapProcessor? = nil
    
    private let annotationSegmentationPipeline = AnnotationSegmentationPipeline()
    @State private var transformedLabelImages: [CIImage]? = nil
    
    @State private var confirmAnnotationFailed: Bool = false
    
    // For deciding the layout
    @StateObject private var orientationObserver = OrientationObserver()
    
    var body: some View {
        if (!self.isValid()) {
            // FIXME: When no segments are available, this view does not dismiss anymore.
            Rectangle().frame(width: 0, height: 0).onAppear {
                refreshView()
            }
        } else {
            orientationStack {
                HStack {
                    Spacer()
                    HostedAnnotationCameraViewController(
                        cameraImage: cameraUIImage!, segmentationImage: segmentationUIImage!, objectsImage: objectsUIImage!
                    )
                    Spacer()
                }
                VStack {
                    HStack {
                        Spacer()
                        Text("\(AnnotationViewConstants.Texts.selectedClassPrefixText): \(Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]])")
                        Spacer()
                    }
                    
                    HStack {
                        Picker(AnnotationViewConstants.Texts.selectObjectText, selection: $selectedObjectId) {
                            ForEach(annotatedDetectedObjects ?? [], id: \.id) { object in
                                Text(object.label ?? "")
                                    .tag(object.id)
                            }
                        }
                    }
                    
                    ProgressBar(value: calculateProgress())
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    selectedOption = (selectedOption == option) ? nil : option
                                    
                                    if option == .misidentified {
                                        selectedClassIndex = index
                                        tempSelectedClassIndex = sharedImageData.segmentedIndices[index]
                                        isShowingClassSelectionModal = true
                                    }
                                }) {
                                    Text(option.rawValue)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(selectedOption == option ? Color.blue : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    
                    Button(action: {
                        confirmAnnotation()
                    }) {
                        Text(index == selection.count - 1 ? AnnotationViewConstants.Texts.finishText : AnnotationViewConstants.Texts.nextText)
                    }
                    .padding()
                }
            }
            .padding(.top, 20)
            .navigationBarTitle(AnnotationViewConstants.Texts.annotationViewTitle, displayMode: .inline)
            .onAppear {
                // Initialize the depthMapProcessor with the current depth image
                depthMapProcessor = DepthMapProcessor(depthImage: sharedImageData.depthImage!)
//                initializeAnnotationSegmentationPipeline()
                refreshView()
            }
            .onChange(of: selectedObjectId) { oldValue, newValue in
                if let newValue = newValue {
                    updateObjectSelection(previousSelectedObjectId: oldValue, selectedObjectId: newValue)
                }
            }
            .onChange(of: index, initial: true) { oldIndex, newIndex in
                // Trigger any additional actions when the index changes
                refreshView()
            }
            .alert(AnnotationViewConstants.Texts.confirmAnnotationFailedTitle, isPresented: $confirmAnnotationFailed) {
                Button(AnnotationViewConstants.Texts.confirmAnnotationFailedCancelText, role: .cancel) {
                    selectedOption = nil
                    nextSegment()
                }
                Button(AnnotationViewConstants.Texts.confirmAnnotationFailedConfirmText) {
                    confirmAnnotationWithoutDepth()
                }
            } message: {
                Text(AnnotationViewConstants.Texts.depthOrSegmentationUnavailableText)
            }
            // TODO: Need to check if the following vetting is necessary
//            .sheet(isPresented: $isShowingClassSelectionModal) {
//                classSelectionView()
//            }
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let isLandscape = CameraOrientation.isLandscapeOrientation(
            currentDeviceOrientation: orientationObserver.deviceOrientation)
        if isLandscape {
            HStack(content: content)
        } else {
            VStack(content: content)
        }
    }
    
    func isValid() -> Bool {
        if (self.sharedImageData.segmentedIndices.isEmpty || (index >= self.sharedImageData.segmentedIndices.count)) {
            print("Invalid index or segmentedIndices in AnnotationView")
            return false
        }
        if (self.cameraUIImage == nil || self.segmentationUIImage == nil || self.objectsUIImage == nil) {
            return false
        }
        return true
    }
    
    func refreshView() {
        print("Calling refreshView")
        if self.transformedLabelImages == nil {
            print("Transformed label images are nil. Initializing annotation segmentation pipeline.")
            self.initializeAnnotationSegmentationPipeline()
        }
        
        setCameraUIImage()
        
        guard index < sharedImageData.segmentedIndices.count else {
            print("Index out of bounds for segmentedIndices in AnnotationView")
            return
        }
        
        let inputLabelImage = setAndReturnSegmentationUIImage()
        
        guard let inputLabelImage = inputLabelImage else {
            print("Input label image is nil")
            return
        }
        let _ = setAndReturnObjectsUIImage(inputLabelImage: inputLabelImage)
    }
    
    /**
     Initializes the annotation segmentation pipeline by processing the image history, to transform each label image to the current image.
     This can be used to set up the union of masks request.
     */
    private func initializeAnnotationSegmentationPipeline() {
        do {
            try self.transformedLabelImages = self.annotationSegmentationPipeline.processTransformationsRequest(
                imageDataHistory: sharedImageData.getImageDataHistory())
            if let transformedLabelImages = self.transformedLabelImages {
                self.annotationSegmentationPipeline.setupUnionOfMasksRequest(segmentationLabelImages: transformedLabelImages)
            }
        } catch {
            print("Error processing transformations request: \(error)")
        }
    }
    
    private func setCameraUIImage() {
        let cameraCGImage = annotationCIContext.createCGImage(
            sharedImageData.cameraImage!, from: sharedImageData.cameraImage!.extent)!
        self.cameraUIImage = UIImage(cgImage: cameraCGImage, scale: 1.0, orientation: .up)
    }
    
    // Perform the union of masks on the label image history for the given segmentation class.
    // Save the resultant image to the segmentedLabelImage property.
    private func setAndReturnSegmentationUIImage() -> CIImage? {
        var inputLabelImage = sharedImageData.segmentationLabelImage
        do {
            inputLabelImage = try self.annotationSegmentationPipeline.processUnionOfMasksRequest(
                targetValue: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]],
                bounds: Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]].bounds
            )
        } catch {
            print("Error processing union of masks request: \(error)")
        }
        self.annotatedSegmentationLabelImage = inputLabelImage
        self.grayscaleToColorMasker.inputImage = inputLabelImage
        self.grayscaleToColorMasker.grayscaleValues = [Constants.ClassConstants.grayscaleValues[sharedImageData.segmentedIndices[index]]]
        self.grayscaleToColorMasker.colorValues = [Constants.ClassConstants.colors[sharedImageData.segmentedIndices[index]]]
        self.segmentationUIImage = UIImage(ciImage: self.grayscaleToColorMasker.outputImage!, scale: 1.0, orientation: .up)
        
        return inputLabelImage
    }
    
    private func setAndReturnObjectsUIImage(inputLabelImage: CIImage) -> [AnnotatedDetectedObject] {
        var inputDetectedObjects: [DetectedObject] = []
        
        // Get the detected objects from the resultant union image.
        do {
            inputDetectedObjects = try self.annotationSegmentationPipeline.processContourRequest(
                from: inputLabelImage,
                targetValue: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]],
                isWay: Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]].isWay,
                bounds: Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]].bounds
            )
        } catch {
            print("Error processing contour request: \(error)")
        }
        var annotatedDetectedObjects = inputDetectedObjects.enumerated().map({ objectIndex, object in
            AnnotatedDetectedObject(object: object, classLabel: object.classLabel, depthValue: 0.0, isAll: false,
                                    label: Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]] + ": " + String(objectIndex))
        })
        // Add the "all" object to the beginning of the list
        annotatedDetectedObjects.insert(
            AnnotatedDetectedObject(object: nil, classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]],
                                    depthValue: 0.0, isAll: true, label: AnnotationViewConstants.Texts.selectAllLabelText),
            at: 0
        )
        self.annotatedDetectedObjects = annotatedDetectedObjects
        self.selectedObjectId = annotatedDetectedObjects[0].id
        self.objectsUIImage = UIImage(
            cgImage: ContourObjectRasterizer.rasterizeContourObjects(
                objects: inputDetectedObjects,
                size: Constants.ClassConstants.inputSize,
                polygonConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
                wayBoundsConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                centroidConfig: RasterizeConfig(draw: true, color: nil, width: 5)
            )!,
            scale: 1.0, orientation: .up)
        
        return annotatedDetectedObjects
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
            baseImage: baseImage, objects: oldObjects, size: Constants.ClassConstants.inputSize,
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
            baseImage: newImage!, objects: newObjects, size: Constants.ClassConstants.inputSize,
            polygonConfig: RasterizeConfig(draw: true, color: .white, width: 2),
            boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
            wayBoundsConfig: RasterizeConfig(draw: true, color: .white, width: 2),
            centroidConfig: RasterizeConfig(draw: true, color: .white, width: 5)
        )
        if let newImage = newImage {
            self.objectsUIImage = UIImage(cgImage: newImage, scale: 1.0, orientation: .up)
        } else { print("Failed to update rasterized image") }
    }
    
    func confirmAnnotation() {
        var depthValue: Float = 0.0
        guard let depthMapProcessor = depthMapProcessor,
              let depthImage = sharedImageData.depthImage,
              let segmentationLabelImage = self.annotatedSegmentationLabelImage,
              let annotatedDetectedObjects = self.annotatedDetectedObjects
        else {
            confirmAnnotationFailed = true
            return
        }
            
        // TODO: Instead of only using the centroid, use a trimmed mean of the depth values of all the pixels in the object.
        for annotatedDetectedObject in annotatedDetectedObjects {
            guard let detectedObject = annotatedDetectedObject.object else { continue }
            depthValue = depthMapProcessor.getDepth(
                segmentationLabelImage: segmentationLabelImage, object: detectedObject,
                depthImage: depthImage,
                classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
            var annotatedDetectedObject = annotatedDetectedObject
            annotatedDetectedObject.depthValue = depthValue
        }
//        let location = objectLocation.getCalcLocation(depthValue: depthValue)
        selectedOption = nil
        uploadAnnotatedChanges(annotatedDetectedObjects: annotatedDetectedObjects)
        nextSegment()
    }
    
    func confirmAnnotationWithoutDepth() {
        selectedOption = nil
        let location = objectLocation.getCalcLocation(depthValue: 0.0)
        let tags: [String: String] = ["demo:class": Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]]]
        // Since the depth calculation failed, we are not going to save this node in sharedImageData for future use.
        uploadNodeWithoutDepth(location: location, tags: tags,
                          classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
        nextSegment()
    }
    
    func nextSegment() {
        // Ensure that the index does not exceed the length of the sharedImageData segmentedIndices count
        // Do not simply rely on the isValid check in the body.
        if (self.index + 1 < sharedImageData.segmentedIndices.count) {
            self.index += 1
        } else {
            self.dismiss()
        }
    }

    func calculateProgress() -> Float {
        return Float(self.index) / Float(self.sharedImageData.segmentedIndices.count)
    }
}

// Extension for uploading the annotated changes to the server
extension AnnotationView {
    // TODO: Instead of passing one request for each object, we should be able to pass all the objects in one request.
    private func uploadAnnotatedChanges(annotatedDetectedObjects: [AnnotatedDetectedObject]) {
        let uploadObjects = annotatedDetectedObjects.filter { $0.object != nil && !$0.isAll }
        guard !uploadObjects.isEmpty else {
            print("No objects to upload")
            return
        }
        
        // We assume that every object is of the same class.
        let currentClass = Constants.ClassConstants.classes.filter {
            $0.labelValue == uploadObjects[0].classLabel
        }.first
        let isWay = currentClass?.isWay ?? false
        if isWay {
            // We upload all the nodes along with the way.
            uploadWay(annotatedDetectedObject: uploadObjects[0], classLabel: uploadObjects[0].classLabel)
        } else {
            // We upload all the nodes.
            uploadNodes(annotatedDetectedObjects: uploadObjects, classLabel: uploadObjects[0].classLabel)
        }
    }
    
    private func uploadWay(annotatedDetectedObject: AnnotatedDetectedObject, classLabel: UInt8) {
        var tempId = -1
        var nodeData = getNodeDataFromAnnotatedObject(
            annotatedDetectedObject: annotatedDetectedObject, id: tempId, isWay: true)
        tempId -= 1
        
        var wayDataOperations: [ChangesetDiffOperation] = []
        if let nodeData = nodeData {
            wayDataOperations.append(ChangesetDiffOperation.create(nodeData))
        }
        
        var wayData = self.sharedImageData.wayGeometries[classLabel]?.last
        // If the wayData is already present, we will modify the existing wayData instead of creating a new one.
        if wayData != nil, wayData?.id != "-1" && wayData?.id != "" {
//            var wayData = wayData!
            if let nodeData = nodeData {
                wayData?.nodeRefs.append(nodeData.id)
            }
            wayDataOperations.append(ChangesetDiffOperation.modify(wayData!))
        } else {
            let classLabelClass = Constants.ClassConstants.classes.filter {
                $0.labelValue == annotatedDetectedObject.classLabel
            }.first
            let className = classLabelClass?.name ?? APIConstants.OtherConstants.classLabelPlaceholder
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
                                                           classLabel: classLabel)
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
                        sharedImageData.wayGeometries[classLabel]?.removeLast()
                        sharedImageData.appendWayGeometry(wayData: wayData!,
                                                          classLabel: classLabel)
                    }
                }
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadNodes(annotatedDetectedObjects: [AnnotatedDetectedObject], classLabel: UInt8) {
        var tempId = -1
        let nodeDataObjects: [NodeData?] = annotatedDetectedObjects.map { object in
            let nodeData = getNodeDataFromAnnotatedObject(
                annotatedDetectedObject: object, id: tempId, isWay: false)
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
                                                           classLabel: classLabel)
                    }
                }
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadNodeWithoutDepth(location: (latitude: CLLocationDegrees, longitude: CLLocationDegrees)?,
                                        tags: [String: String], classLabel: UInt8) {
        guard let nodeLatitude = location?.latitude,
              let nodeLongitude = location?.longitude
        else { return }
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
                                                           classLabel: classLabel)
                    }
                }
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func getNodeDataFromAnnotatedObject(
        annotatedDetectedObject: AnnotatedDetectedObject,
        id: Int, isWay: Bool = false
    ) -> NodeData? {
        let location = objectLocation.getCalcLocation(depthValue: annotatedDetectedObject.depthValue)
        guard let nodeLatitude = location?.latitude,
              let nodeLongitude = location?.longitude
        else { return nil }
        
        let classLabelClass = Constants.ClassConstants.classes.filter {
            $0.labelValue == annotatedDetectedObject.classLabel
        }.first
        let className = classLabelClass?.name ?? APIConstants.OtherConstants.classLabelPlaceholder
        var tags: [String: String] = [APIConstants.TagKeys.classKey: className]
        
        if isWay {
            let width = objectLocation.getWayWidth(wayBounds: annotatedDetectedObject.object?.wayBounds ?? [],
                                                   imageSize: segmentationUIImage?.size ?? CGSize.zero)
            tags[APIConstants.TagKeys.widthKey] = String(format: "%.4f", width)
        }
        
        let nodeData = NodeData(id: String(id),
                                latitude: nodeLatitude, longitude: nodeLongitude, tags: tags)
        return nodeData
    }
}

// Extension for loading the ClassSelectionView as sheet
extension AnnotationView {
    @ViewBuilder
    func classSelectionView() -> some View {
        if let selectedClassIndex = selectedClassIndex {
            let filteredClasses = selection.map { Constants.ClassConstants.classNames[$0] }
            
            // mapping between filtered and non-filtered
            let selectedFilteredIndex = selection.firstIndex(of: sharedImageData.segmentedIndices[selectedClassIndex]) ?? 0
            
            let selectedClassBinding: Binding<Array<Int>.Index> = Binding(
                get: { selectedFilteredIndex },
                set: { newValue in
                    let originalIndex = selection[newValue]
                    // Update the segmentedIndices inside sharedImageData
                    sharedImageData.segmentedIndices[selectedClassIndex] = originalIndex
                }
            )
            
            ClassSelectionView(
                classes: filteredClasses,
                selectedClass: selectedClassBinding
            )
        }
    }
}

struct ClassSelectionView: View {
    var classes: [String]
    @Binding var selectedClass: Int
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text(AnnotationViewConstants.Texts.selectCorrectAnnotationText)
                .font(.headline)
                .padding()

            List {
                ForEach(0..<classes.count, id: \.self) { index in
                    Button(action: {
                        selectedClass = index
                    }) {
                        HStack {
                            Text(classes[index])
                            Spacer()
                            if selectedClass == index {
                                Image(systemName: AnnotationViewConstants.Images.checkIcon)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text(AnnotationViewConstants.Texts.doneText)
                    .padding()
            }
        }
    }
}
