//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import CoreLocation

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
    
    init(object: DetectedObject?, classLabel: UInt8, depthValue: Float, isAll: Bool = false, label: String? = "Select All") {
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
    
    let annotationCIContext = CIContext()
    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    @State private var depthMapProcessor: DepthMapProcessor? = nil
    
    let annotationSegmentationPipeline = AnnotationSegmentationPipeline()
    @State var transformedLabelImages: [CIImage]? = nil
    
    var body: some View {
        if (!self.isValid()) {
            // FIXME: When no segments are available, this view does not dismiss anymore.
            Rectangle().frame(width: 0, height: 0).onAppear {
                refreshView()
            }
        } else {
            VStack {
                HStack {
                    Spacer()
                    HostedAnnotationCameraViewController(cameraImage: cameraUIImage!,
                                                         segmentationImage: segmentationUIImage!,
                                                         objectsImage: objectsUIImage!,
                                                            frameRect: VerticalFrame.getColumnFrame(
                                                            width: UIScreen.main.bounds.width,
                                                            height: UIScreen.main.bounds.height,
                                                            row: 0)
                    )
                    Spacer()
                }
                HStack {
                    Spacer()
                    Text("Selected class: \(Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]])")
                    Spacer()
                }
                
                HStack {
                    Picker("Select an object", selection: $selectedObjectId) {
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
                    Text(index == selection.count - 1 ? "Finish" : "Next")
                }
                .padding()
            }
            .navigationBarTitle("Annotation View", displayMode: .inline)
            .onAppear {
                // Initialize the depthMapProcessor with the current depth image
                depthMapProcessor = DepthMapProcessor(depthImage: sharedImageData.depthImage!)
//                initializeAnnotationSegmentationPipeline()
                refreshView()
            }
//            .onDisappear {
//                closeChangeset()
//            }
            .onChange(of: selectedObjectId) { oldValue, newValue in
                if let newValue = newValue {
                    updateAnnotatedDetectedSelection(previousSelectedObjectId: oldValue, selectedObjectId: newValue)
                }
            }
            .onChange(of: index, initial: true) { oldIndex, newIndex in
                // Trigger any additional actions when the index changes
                refreshView()
            }
            // TODO: Need to check if the following vetting is necessary
            .sheet(isPresented: $isShowingClassSelectionModal) {
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
        if self.transformedLabelImages == nil {
            print("Transformed label images are nil. Initializing annotation segmentation pipeline.")
            self.initializeAnnotationSegmentationPipeline()
        }
        
        let cameraCGImage = annotationCIContext.createCGImage(
            sharedImageData.cameraImage!, from: sharedImageData.cameraImage!.extent)!
        self.cameraUIImage = UIImage(cgImage: cameraCGImage, scale: 1.0, orientation: .up)
//        self.cameraUIImage = UIImage(ciImage: sharedImageData.depthImage!, scale: 1.0, orientation: .up)
        
        guard index < sharedImageData.segmentedIndices.count else {
            print("Index out of bounds for segmentedIndices in AnnotationView")
            return
        }
        
        var inputImage = sharedImageData.segmentationLabelImage
        var unionOfMasksObjects: [DetectedObject] = []
        do {
            let unionOfMasksResults = try self.annotationSegmentationPipeline.processUnionOfMasksRequest(
                targetValue: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]],
                isWay: Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]].isWay,
                bounds: Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]].bounds
            )
            if let unionOfMasksResults = unionOfMasksResults {
                inputImage = unionOfMasksResults.segmentationImage
                unionOfMasksObjects = unionOfMasksResults.detectedObjects
            } else {
                print("Failed to create union image")
            }
        } catch {
            print("Error processing union of masks request: \(error)")
        }
        
        self.annotatedSegmentationLabelImage = inputImage
        var annotatedDetectedObjects = unionOfMasksObjects.enumerated().map({ objectIndex, object in
            AnnotatedDetectedObject(object: object,
                                    classLabel: object.classLabel,
                                    depthValue: 0.0,
                                    isAll: false,
                                    label: Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]] + ": " + String(objectIndex)
            )
        })
        // Add the "all" object to the beginning of the list
        annotatedDetectedObjects.insert(
            AnnotatedDetectedObject(
                object: nil,
                classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]],
                depthValue: 0.0,
                isAll: true,
                label: "Select All"
            ),
            at: 0
        )
        self.annotatedDetectedObjects = annotatedDetectedObjects
        self.selectedObjectId = annotatedDetectedObjects[0].id
        
        self.grayscaleToColorMasker.inputImage = inputImage
        self.grayscaleToColorMasker.grayscaleValues = [Constants.ClassConstants.grayscaleValues[sharedImageData.segmentedIndices[index]]]
        self.grayscaleToColorMasker.colorValues = [Constants.ClassConstants.colors[sharedImageData.segmentedIndices[index]]]
        self.segmentationUIImage = UIImage(ciImage: self.grayscaleToColorMasker.outputImage!, scale: 1.0, orientation: .up)
        self.objectsUIImage = UIImage(
            cgImage: ContourObjectRasterizer.rasterizeContourObjects(
                objects: unionOfMasksObjects,
                size: Constants.ClassConstants.inputSize,
                polygonConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
                wayBoundsConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                centroidConfig: RasterizeConfig(draw: true, color: nil, width: 5)
            )!,
            scale: 1.0, orientation: .up)
        
//        let segmentationCGSize = CGSize(width: sharedImageData.segmentationLabelImage!.extent.width,
//                                            height: sharedImageData.segmentationLabelImage!.extent.height)
//        let segmentationObjects = sharedImageData.detectedObjects.filter { objectID, object in
//            object.classLabel == Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]] &&
//            object.isCurrent == true
//        } .map({ $0.value })
//        let segmentationObjectImage = ContourObjectRasterizer.rasterizeContourObjects(objects: segmentationObjects, size: segmentationCGSize)
//        self.segmentationUIImage = UIImage(ciImage: segmentationObjectImage!, scale: 1.0, orientation: .up)
    }
    
    private func initializeAnnotationSegmentationPipeline() {
        do {
            try self.transformedLabelImages = self.annotationSegmentationPipeline.processTransformationsRequest(
                imageDataHistory: sharedImageData.getImageDataHistory())
            if let transformedLabelImages = self.transformedLabelImages {
                print("Transformed label images count: \(transformedLabelImages.count)")
                self.annotationSegmentationPipeline.setupUnionOfMasksRequest(segmentationLabelImages: transformedLabelImages)
            }
        } catch {
            print("Error processing transformations request: \(error)")
        }
    }
    
    func updateAnnotatedDetectedSelection(previousSelectedObjectId: UUID?, selectedObjectId: UUID) {
        if let baseImage = self.objectsUIImage?.cgImage {
            var oldObjects: [DetectedObject] = []
            var newObjects: [DetectedObject] = []
            var newImage: CGImage?
            if previousSelectedObjectId != nil {
                for object in self.annotatedDetectedObjects ?? [] {
                    if object.id == previousSelectedObjectId! {
                        if object.object != nil { oldObjects.append(object.object!) }
                        break
                    }
                }
            }
            newImage = ContourObjectRasterizer.updateRasterizedImage(
                baseImage: baseImage,
                objects: oldObjects,
                size: Constants.ClassConstants.inputSize,
                polygonConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
                wayBoundsConfig: RasterizeConfig(draw: true, color: nil, width: 2),
                centroidConfig: RasterizeConfig(draw: true, color: nil, width: 5)
            )
            for object in self.annotatedDetectedObjects ?? [] {
                if object.id == selectedObjectId {
                    if object.object != nil { newObjects.append(object.object!) }
                    break
                }
            }
            if newImage == nil {
                print("Failed to update rasterized image")
                return
            }
            newImage = ContourObjectRasterizer.updateRasterizedImage(
                baseImage: newImage!,
                objects: newObjects,
                size: Constants.ClassConstants.inputSize,
                polygonConfig: RasterizeConfig(draw: true, color: .white, width: 2),
                boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
                wayBoundsConfig: RasterizeConfig(draw: true, color: .white, width: 2),
                centroidConfig: RasterizeConfig(draw: true, color: .white, width: 5)
            )
            if let newImage = newImage {
                self.objectsUIImage = UIImage(cgImage: newImage, scale: 1.0, orientation: .up)
            } else {
                print("Failed to update rasterized image")
            }
        }
    }
    
    func confirmAnnotation() {
        var depthValue: Float = 0.0
        
        // TODO: Give the user some explicit warning that the depth is not being calculated
        // due to which the entire annotations are being ignored.
        guard let depthMapProcessor = depthMapProcessor,
//            let segmentationLabelImage = sharedImageData.segmentationLabelImage,
            let depthImage = sharedImageData.depthImage
        else {
            print("depthMapProcessor is nil. Returning.")
            selectedOption = nil
            let location = objectLocation.getCalcLocation(depthValue: depthValue)
            let tags: [String: String] = ["demo:class": Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]]]
            // Since the depth calculation failed, we are not going to save this node in sharedImageData for future use.
            uploadNodeChanges(location: location, tags: tags,
                              classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
            nextSegment()
            return
        }
        
        guard let segmentationLabelImage = self.annotatedSegmentationLabelImage,
              let annotatedDetectedObjects = self.annotatedDetectedObjects
        else {
            print("annotatedDetectedObjects is nil. Returning.")
            selectedOption = nil
            let location = objectLocation.getCalcLocation(depthValue: depthValue)
            let tags: [String: String] = ["demo:class": Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]]]
            // Since the depth calculation failed, we are not going to save this node in sharedImageData for future use.
            uploadNodeChanges(location: location, tags: tags,
                              classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
            nextSegment()
            return
        }
        
            
        // TODO: Temporary object-based depth calculation.
        // This logic currently only utilizes the centroid of the last detected object.
        // This eventually needs to be extended to do 2 more things:
        // 1. Treat every object as a separate object and calculate the depth value for each of them and upload them.
        // 2. Instead of only using the centroid, use a trimmed mean of the depth values of all the pixels in the object.
        for annotatedDetectedObject in annotatedDetectedObjects {
            guard let detectedObject = annotatedDetectedObject.object else {
                continue
            }
            depthValue = depthMapProcessor.getDepth(
                segmentationLabelImage: segmentationLabelImage, object: detectedObject,
                depthImage: depthImage,
                classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
            print("Depth Value for Label: \(depthValue) Object: \(String(describing: annotatedDetectedObject.object?.centroid))")
            var annotatedDetectedObject = annotatedDetectedObject
            annotatedDetectedObject.depthValue = depthValue
        }
//        let location = objectLocation.getCalcLocation(depthValue: depthValue)
        selectedOption = nil
        uploadAnnotatedChanges(annotatedDetectedObjects: annotatedDetectedObjects)
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
    
    // TODO: Instead of passing one request for each object, we should be able to pass all the objects in one request.
    private func uploadAnnotatedChanges(annotatedDetectedObjects: [AnnotatedDetectedObject]) {
        for annotatedDetectedObject in annotatedDetectedObjects {
            if annotatedDetectedObject.isAll {
                continue
            }
            self.uploadAnnotatedChange(annotatedDetectedObject: annotatedDetectedObject)
        }
    }
    
    private func uploadAnnotatedChange(annotatedDetectedObject: AnnotatedDetectedObject) {
        let location = objectLocation.getCalcLocation(depthValue: annotatedDetectedObject.depthValue)
        
        let classLabelClass = Constants.ClassConstants.classes.filter {
            $0.labelValue == annotatedDetectedObject.classLabel
        }.first
        
        let className = classLabelClass?.name ?? "Unknown"
        var tags: [String: String] = ["demo:class": className]
        
        // Check if way type
        let isWay = classLabelClass?.isWay ?? false
        guard isWay else {
            uploadNodeChanges(location: location, tags: tags, classLabel: annotatedDetectedObject.classLabel)
            return
        }
        let width = objectLocation.getWayWidth(wayBounds: annotatedDetectedObject.object?.wayBounds ?? [],
                                               imageSize: segmentationUIImage?.size ?? CGSize.zero)
        
        var wayTags: [String: String] = ["demo:class": className]
        tags["demo:width"] = String(format: "%.4f", width)
//        wayTags["footway"] = className.lowercased()
        uploadNodeChanges(location: location, tags: tags, classLabel: annotatedDetectedObject.classLabel,
                           wayTags: wayTags)
    }
    
    // TODO: This is a temporary set up of wayTags to test what is possible. Need to segregate these functionalities
    private func uploadNodeChanges(
        location: (latitude: CLLocationDegrees, longitude: CLLocationDegrees)?, tags: [String: String], classLabel: UInt8,
        wayTags: [String: String]? = nil
    ) {
        guard let nodeLatitude = location?.latitude,
              let nodeLongitude = location?.longitude
        else { return }
        var nodeData = NodeData(latitude: nodeLatitude, longitude: nodeLongitude, tags: tags)
        
        ChangesetService.shared.createNode(nodeData: nodeData) { result in
            switch result {
            case .success(let response):
                print("Changes uploaded successfully.")
                DispatchQueue.main.async {
                    sharedImageData.isUploadReady = true
                    
                    if let response = response,
                        let nodeAttributes = response["node"] {
                        nodeData.id = nodeAttributes["new_id"] ?? "-1"
                        nodeData.version = nodeAttributes["new_version"] ?? "-1"
                    }
                    
                    sharedImageData.appendNodeGeometry(nodeData: nodeData, classLabel: classLabel)
                    
                    if let wayTags = wayTags {
                        self.uploadWayChanges(nodeData: nodeData, tags: wayTags, classLabel: classLabel)
                    }
                }
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadWayChanges(nodeData: NodeData?, tags: [String: String], classLabel: UInt8) {
        if let wayData = self.sharedImageData.wayGeometries[classLabel]?.last,
           wayData.id != "-1" && wayData.id != "" {
            var wayData = wayData
            if (nodeData != nil && nodeData?.id != "" && nodeData?.id != "-1") {
                wayData.nodeRefs.append(nodeData!.id)
            }
            // Modify the existing way
            ChangesetService.shared.modifyWay(wayData: wayData) { result in
                switch result {
                case .success(let response):
                    print("Changes uploaded successfully.")
                    DispatchQueue.main.async {
                        sharedImageData.isUploadReady = true
                        
                        if let response = response,
                           let wayAttributes = response["way"] {
                            wayData.id = wayAttributes["new_id"] ?? "-1"
                            wayData.version = wayAttributes["new_version"] ?? "-1"
                        }
                        sharedImageData.wayGeometries[classLabel]?.removeLast()
                        sharedImageData.appendWayGeometry(wayData: wayData, classLabel: classLabel)
                    }
                case .failure(let error):
                    print("Failed to upload changes: \(error.localizedDescription)")
                }
            }
        } else {
            // Create a new way
            var nodeRefs: [String] = []
            if (nodeData != nil && nodeData?.id != "" && nodeData?.id != "-1") {
                nodeRefs.append(nodeData!.id)
            }
            var wayData = WayData(tags: tags, nodeRefs: nodeRefs)
            
            ChangesetService.shared.createWay(wayData: wayData) { result in
                switch result {
                case .success(let response):
                    print("Changes uploaded successfully.")
                    DispatchQueue.main.async {
                        sharedImageData.isUploadReady = true
                        
                        if let response = response,
                           let wayAttributes = response["way"] {
                            wayData.id = wayAttributes["new_id"] ?? "-1"
                            wayData.version = wayAttributes["new_version"] ?? "-1"
                        }
                        sharedImageData.appendWayGeometry(wayData: wayData, classLabel: classLabel)
                    }
                case .failure(let error):
                    print("Failed to upload changes: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ClassSelectionView: View {
    var classes: [String]
    @Binding var selectedClass: Int
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Select correct annotation")
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
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .padding()
            }
        }
    }
}
