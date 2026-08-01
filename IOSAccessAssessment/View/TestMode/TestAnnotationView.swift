//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/10/25.
//

import SwiftUI
import TipKit
import CoreLocation
import simd
import PointNMapShared

struct TestAnnotationView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    let selectedAttributesByClass: [AccessibilityFeatureClass: Set<AccessibilityFeatureAttribute>]
    let captureLocation: CLLocationCoordinate2D
    let correctedLocation: CLLocationCoordinate2D?
    let apiChangesetUploadController: APIChangesetUploadController
    
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject var sharedAppData: SharedAppData
    @Environment(\.dismiss) var dismiss
    
    @StateObject var manager: AnnotationImageManager = AnnotationImageManager<MappedEditableAccessibilityFeature>()
    
    @StateObject var segmentationAnnontationPipeline: SegmentationAnnotationPipeline = SegmentationAnnotationPipeline()
    @StateObject var attributeEstimationPipeline: AttributeEstimationPipeline = AttributeEstimationPipeline()
    
    @StateObject private var managerStatusViewModel = AnnotationViewStatusViewModel()
    @StateObject private var apiChangesetUploadStatusViewModel = APIChangesetUploadStatusViewModel()
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait // To bind one-way with manager's orientation
    
    @StateObject var featureClassSelectionViewModel = AnnotationFeatureClassSelectionViewModel()
    @StateObject var featureSelectionViewModel = AnnotationFeatureSelectionViewModel()
    @State private var isShowingAnnotationFeatureDetailView: Bool = false
    
//    var selectFeatureInfoTip = SelectFeatureInfoTip()
    @State private var showSelectFeatureLearnMoreSheet = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(AnnotationViewConstants.Texts.annotationViewTitle)
                    .font(.headline)
                    .padding()
                Spacer()
            }
            .overlay(
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: AnnotationViewConstants.Images.closeIcon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .padding()
                }
            )
            
            if let currentClass = featureClassSelectionViewModel.currentClass {
                mainContent(currentClass: currentClass)
            } else {
                loadingPageView()
            }
        }
        .task {
            await handleOnAppear()
        }
        .onChange(of: featureClassSelectionViewModel.currentClass) { oldClass, newClass in
            handleOnClassChange()
        }
        /// We are using index to track change in instance, instead of the instance itself, because we want to use the index for naming the instance in the picker.
        /// To use the instance directly would require AccessibilityFeature to conform to Hashable, which is possible, by just using id.
        /// But while rendering the picker, we would need to create a new Array of enumerated instances, which would be less efficient.
        .onChange(of: featureSelectionViewModel.currentIndex) { oldIndex, newIndex in
            handleOnInstanceChange(oldIndex: oldIndex, newIndex: newIndex)
        }
        .sheet(isPresented: $isShowingAnnotationFeatureDetailView) {
            if let currentFeature = featureSelectionViewModel.currentFeature,
               let currentFeatureIndex = featureSelectionViewModel.currentIndex
            {
                AnnotationFeatureDetailView(
                    accessibilityFeature: currentFeature,
                    title: "\(currentFeature.accessibilityFeatureClass.name.capitalized): \(currentFeatureIndex)"
                )
                    .presentationDetents([.medium, .large])
            } else {
                Text(AnnotationViewConstants.Texts.featureDetailNotAvailableText)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showSelectFeatureLearnMoreSheet) {
            SelectFeatureLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
        .alert(AnnotationViewConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerStatusViewModel.isFailed, actions: {
            Button(AnnotationViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                let shouldDismiss = managerStatusViewModel.shouldDismiss
                managerStatusViewModel.update(isFailed: false, errorMessage: "")
                if shouldDismiss {
                    dismiss()
                }
            }
        }, message: {
            Text(managerStatusViewModel.errorMessage)
        })
        .alert(AnnotationViewConstants.Texts.apiChangesetUploadStatusAlertTitleKey,
               isPresented: $apiChangesetUploadStatusViewModel.isFailed, actions: {
            Button(AnnotationViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                apiChangesetUploadStatusViewModel.update(isFailed: false, errorMessage: "")
                do {
                    try moveToNextClass()
                } catch {
                    managerStatusViewModel.update(isFailed: true, error: error)
                }
            }
        }, message: {
            Text(apiChangesetUploadStatusViewModel.errorMessage)
        })
    }
    
    private func loadingPageView() -> some View {
        VStack {
            Spacer()
            Text(AnnotationViewConstants.Texts.loadingPageText)
            SpinnerView()
            Spacer()
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        manager.interfaceOrientation.isLandscape ?
        AnyLayout(HStackLayout())(content) :
        AnyLayout(VStackLayout())(content)
    }
    
    @ViewBuilder
    private func mainContent(currentClass: AccessibilityFeatureClass) -> some View {
        let isDisabledFeatureDetailButton = featureSelectionViewModel.currentFeature == nil
        orientationStack {
            HostedAnnotationImageViewController<MappedEditableAccessibilityFeature>(annotationImageManager: manager)
            
            VStack {
                HStack {
                    Spacer()
                    Text("\(AnnotationViewConstants.Texts.currentClassPrefixText): \(currentClass.name)")
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    CustomPicker (
                        label: AnnotationViewConstants.Texts.selectObjectText,
                        selection: $featureSelectionViewModel.currentIndex,
//                        isContainsAll: currentClass.kind.oswPolicy.oswElementClass != .Sidewalk
                        isContainsAll: currentClass.kind.isUniquePerCapture == false
                    ) {
                        ForEach(featureSelectionViewModel.instances.indices, id: \.self) { featureIndex in
                            Text("\(currentClass.name.capitalized): \(featureIndex)")
                                .tag(featureIndex as Int?)
                        }
                    }
                    Button(action: {
                        isShowingAnnotationFeatureDetailView = true
                    }) {
                        Image(systemName: AnnotationViewConstants.Images.ellipsisIcon)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 5)
                    .disabled(isDisabledFeatureDetailButton)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .overlay(
                    HStack {
                        Spacer()
                        Button(action: {
                            showSelectFeatureLearnMoreSheet = true
                        }) {
                            Image(systemName: AnnotationViewConstants.Images.infoIcon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .padding(.trailing, 10)
                    }
                )
                
                ProgressBar(value: 0)
                
                HStack {
                    Spacer()
                    annotationOptionsView(currentClass: currentClass)
                    Spacer()
                }
                .padding()
                
                Button(action: {
                    confirmAnnotation()
                }) {
                    Text(isCurrentIndexLast() ? AnnotationViewConstants.Texts.finishText : AnnotationViewConstants.Texts.nextText)
                        .padding()
                }
            }
        }
    }
    
    private func annotationOptionsView(currentClass: AccessibilityFeatureClass) -> some View {
        if let currentFeature = featureSelectionViewModel.currentFeature {
            let annotationOptions: [AnnotationOption] = AnnotationOptionFeature.allCases.map { .individualOption($0) }
            return VStack(spacing: 10) {
                ForEach(annotationOptions, id: \.self) { option in
                    Button(action: {
                        featureSelectionViewModel.setOptionOnFeature(option: option)
                    }) {
                        Text(option.rawValue)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(currentFeature.selectedAnnotationOption == option ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                }
            }
        } else {
            let annotationOptions: [AnnotationOption] = AnnotationOptionFeatureClass.allCases.map { .classOption($0) }
            return VStack(spacing: 10) {
                ForEach(annotationOptions, id: \.self) { option in
                    Button(action: {
                        featureClassSelectionViewModel.setOption(option: option)
                    }) {
                        Text(option.rawValue)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(featureClassSelectionViewModel.selectedAnnotationOption == option ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    private func isCurrentIndexValid() -> Bool {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let currentClassIndex = featureClassSelectionViewModel.currentIndex else {
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.imageData.captureImageDataResults.segmentedClasses
        return (currentClassIndex >= 0 && currentClassIndex < segmentedClasses.count)
    }
    
    private func isCurrentIndexLast() -> Bool {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let currentClassIndex = featureClassSelectionViewModel.currentIndex else {
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.imageData.captureImageDataResults.segmentedClasses
        return currentClassIndex == segmentedClasses.count - 1
    }
    
    private func handleOnAppear() async {
        do {
            guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            var captureMeshData: (any CaptureMeshDataProtocol)? = nil
            if userStateViewModel.isEnhancedAnalysisEnabled {
                guard let captureMeshDataResults = currentCaptureDataRecord.meshData?.captureMeshDataResults else {
                    throw AnnotationViewError.invalidCaptureDataRecord
                }
                captureMeshData = CaptureImageAndMeshData(
                    captureImageData: CaptureImageData(currentCaptureDataRecord.imageData),
                    captureMeshDataResults: captureMeshDataResults
                )
            }
            let segmentedClasses = currentCaptureDataRecord.imageData.captureImageDataResults.segmentedClasses
            try segmentationAnnontationPipeline.configure()
            try attributeEstimationPipeline.configure(
                captureImageData: currentCaptureDataRecord.imageData,
                /// TODO: MESH PROCESSING: Enable mesh data processing
                captureMeshData: captureMeshData
            )
            try manager.configure(
                selectedClasses: selectedClasses, segmentationAnnotationPipeline: segmentationAnnontationPipeline,
                captureImageData: currentCaptureDataRecord.imageData,
                captureMeshData: captureMeshData,
                isEnhancedAnalysisEnabled: userStateViewModel.isEnhancedAnalysisEnabled
            )
            let captureDataHistory = Array(await sharedAppData.captureDataQueue.snapshot())
            manager.setupAlignedSegmentationLabelImages(captureDataHistory: captureDataHistory)
            try featureClassSelectionViewModel.setCurrent(index: 0, classes: segmentedClasses)
        } catch {
            managerStatusViewModel.update(isFailed: true, error: error)
        }
    }
    
    private func handleOnClassChange() {
        do {
            guard let currentClass = featureClassSelectionViewModel.currentClass else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            let accessibilityFeatures = try manager.updateFeatureClass(accessibilityFeatureClass: currentClass)
            var lastEstimationError: Error? = nil
            accessibilityFeatures.forEach { accessibilityFeature in
                // Run for both capture location and corrected location
                do {
//                    try attributeEstimationPipeline.setPrerequisites(accessibilityFeature: accessibilityFeature)
                    try attributeEstimationPipeline.processLocationRequestTypeBased(
                        deviceLocation: captureLocation,
                        accessibilityFeature: accessibilityFeature
                    )
                    attributeEstimationPipeline.processIsExistingRequest(
                        deviceLocation: captureLocation,
                        mappingData: sharedAppData.currentMappingData, accessibilityFeature: accessibilityFeature
                    )
                    attributeEstimationPipeline.processNearestFeaturesRequest(
                        deviceLocation: captureLocation,
                        mappingData: sharedAppData.currentMappingData,
                        accessibilityFeature: accessibilityFeature
                    )
                    try attributeEstimationPipeline.processAttributeRequest(
                        accessibilityFeature: accessibilityFeature,
                        attributes: selectedAttributesByClass[currentClass] ?? []
                    )
                    attributeEstimationPipeline.clearPrerequisites()
                } catch {
                    lastEstimationError = error
                }
                if let correctedLocation {
                    do {
                        try attributeEstimationPipeline.processLocationRequestTypeBased(
                            deviceLocation: correctedLocation,
                            accessibilityFeature: accessibilityFeature,
                            locationType: .correctedLocation
                        )
                        attributeEstimationPipeline.processIsExistingRequest(
                            deviceLocation: correctedLocation,
                            mappingData: sharedAppData.currentMappingData, accessibilityFeature: accessibilityFeature,
                            locationType: .correctedLocation
                        )
                        attributeEstimationPipeline.processNearestFeaturesRequest(
                            deviceLocation: correctedLocation,
                            mappingData: sharedAppData.currentMappingData,
                            accessibilityFeature: accessibilityFeature,
                            locationType: .correctedLocation
                        )
                        attributeEstimationPipeline.clearPrerequisites()
                    } catch {
                        lastEstimationError = error
                    }
                }
            }
            featureClassSelectionViewModel.setOption(option: .classOption(.default))
            try featureSelectionViewModel.setInstances(accessibilityFeatures, currentClass: currentClass)
            if let lastEstimationError {
                throw AnnotationViewError.attributeEstimationFailed(lastEstimationError)
            }
        } catch AnnotationViewError.attributeEstimationFailed(let error) {
            managerStatusViewModel.update(
                isFailed: true, error: AnnotationViewError.attributeEstimationFailed(error), shouldDismiss: false
            )
        } catch {
            managerStatusViewModel.update(isFailed: true, error: error, shouldDismiss: false)
        }
    }
    
    private func handleOnInstanceChange(oldIndex: Int?, newIndex: Int?) {
        do {
            try featureSelectionViewModel.setIndex(index: featureSelectionViewModel.currentIndex)
        } catch {
            managerStatusViewModel.update(isFailed: true, error: error)
        }
        do {
            guard let currentClass = featureClassSelectionViewModel.currentClass else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            var accessibilityFeatures: [MappedEditableAccessibilityFeature]
            var featureSelectedStatus: [UUID: Bool] = [:]
            var updateFeatureResults: AnnotationImageFeatureUpdateResults? = nil
            if let currentFeature = featureSelectionViewModel.currentFeature {
                accessibilityFeatures = [currentFeature]
                featureSelectedStatus[currentFeature.id] = true /// Selected and highlighted
                if let oldIndex = oldIndex, oldIndex != featureSelectionViewModel.currentIndex,
                   oldIndex >= 0, oldIndex < featureSelectionViewModel.instances.count {
                    let oldFeature = featureSelectionViewModel.instances[oldIndex]
                    accessibilityFeatures.append(oldFeature)
                    featureSelectedStatus[oldFeature.id] = false /// Selected, but not highlighted
                }
                /// MARK: Temporary code for visualization. Incurs significant performance overhead.
                /// TODO: Check what happens when we use the cache-based methods instead
                if currentClass.kind.attributes.contains(where: {
                    $0 == .width || $0 == .runningSlope || $0 == .crossSlope || $0 == .surfaceIntegrity
                }) {
                    let worldPoints = try attributeEstimationPipeline.getWorldPoints(accessibilityFeature: currentFeature)
                    let plane = try attributeEstimationPipeline.calculateAlignedPlane(
                        accessibilityFeature: currentFeature, worldPoints: worldPoints
                    )
                    let projectedPlane = try attributeEstimationPipeline.calculateProjectedPlane(
                        accessibilityFeature: currentFeature, plane: plane
                    )
                    let damageDetectionResults = try attributeEstimationPipeline.getDamageDetectionResults(
                        accessibilityFeature: currentFeature
                    )
                    updateFeatureResults = AnnotationImageFeatureUpdateResults(
                        plane: plane, projectedPlane: projectedPlane,
                        damageDetectionResults: damageDetectionResults
                    )
                }
            } else {
                accessibilityFeatures = featureSelectionViewModel.instances
                featureSelectedStatus = featureSelectionViewModel.instances.reduce(into: [:]) { dict, feature in
                    dict[feature.id] = false /// Selected, but not highlighted
                }
            }
//            let isSelected = featureSelectionViewModel.currentFeature != nil
            try manager.updateFeature(
                accessibilityFeatureClass: currentClass,
                accessibilityFeatures: accessibilityFeatures,
                featureSelectedStatus: featureSelectedStatus,
                updateFeatureResults: updateFeatureResults
            )
        } catch {
            managerStatusViewModel.update(isFailed: true, error: error, shouldDismiss: false)
        }
    }
    
    private func confirmAnnotation() {
        Task {
            do {
                let apiChangesetUploadResults = try await uploadFeatures()
                if let apiChangesetUploadResults, apiChangesetUploadResults.failedFeatureUploads > 0 {
                    throw AnnotationViewError.apiChangesetUploadFailed(apiChangesetUploadResults)
                }
                try moveToNextClass()
            } catch AnnotationViewError.classIndexOutofBounds {
                managerStatusViewModel.update(isFailed: true, error: AnnotationViewError.classIndexOutofBounds)
            } catch AnnotationViewError.apiChangesetUploadFailed(let results) {
                apiChangesetUploadStatusViewModel.update(apiChangesetUploadResults: results)
            } catch {
                apiChangesetUploadStatusViewModel.update(
                    isFailed: true,
                    errorMessage: AnnotationViewConstants.Texts.apiChangesetUploadStatusAlertGenericMessageKey
                )
            }
        }
    }
    
    /// Fetches the latest map data for the current location and workspace, and updates the sharedAppData's currentMappingData.
    /// This ensures that the most up-to-date map data is used for the next class's annotation, in case there were any changes from the previous upload.
    /// May be used as a fail-safe if API changeset upload fails, to ensure that the user is working with the latest map data. If the upload is successful, the map data is already updated in the sharedAppData within the uploadFeatures function, so this would just be an extra fetch that may not be necessary.
    private func refreshMap() async throws {
        guard let workspaceId = workspaceViewModel.workspaceId else {
            throw ARCameraViewError.workspaceConfigurationFailed
        }
        guard let accessToken = userStateViewModel.getAccessToken() else {
            throw ARCameraViewError.authenticationError
        }
        let mapData = try await WorkspaceService.shared.fetchMapData(
            workspaceId: workspaceId,
            location: captureLocation,
            radius: SharedAppConstants.WorkspaceConstants.fetchRadiusInMeters,
            accessToken: accessToken,
            environment: userStateViewModel.selectedEnvironment
        )
        sharedAppData.currentMappingData.replace(
            osmMapDataResponse: mapData,
            accessibilityFeatureClasses: selectedClasses
        )
    }
    
    private func moveToNextClass() throws {
        if isCurrentIndexLast() {
            self.dismiss()
            return
        }
        /// Move to next class
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let currentClassIndex = featureClassSelectionViewModel.currentIndex else {
            throw AnnotationViewError.invalidCaptureDataRecord
        }
        let segmentedClasses = currentCaptureDataRecord.imageData.captureImageDataResults.segmentedClasses
        try featureClassSelectionViewModel.setCurrent(index: currentClassIndex + 1, classes: segmentedClasses)
    }
    
    private func uploadFeatures() async throws -> APIChangesetUploadResults? {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord else {
            throw AnnotationViewError.invalidCaptureDataRecord
        }
        guard let workspaceId = workspaceViewModel.workspaceId,
              let changesetId = workspaceViewModel.changesetId else {
            throw AnnotationViewError.workspaceConfigurationFailed
        }
        guard let accessToken = userStateViewModel.getAccessToken() else {
            throw AnnotationViewError.authenticationError
        }
        guard let accessibilityFeatureClass = featureClassSelectionViewModel.currentClass else {
            throw AnnotationViewError.classIndexOutofBounds
        }
        guard featureClassSelectionViewModel.selectedAnnotationOption != .classOption(.discard) else {
            return nil
        }
        let featuresToUpload: [MappedEditableAccessibilityFeature] = featureSelectionViewModel.instances.filter { feature in
            feature.selectedAnnotationOption != .individualOption(.discard) &&
            feature.accessibilityFeatureClass == accessibilityFeatureClass
        }
        guard !featuresToUpload.isEmpty else {
            return nil
        }
        let apiChangesetUploadInputs = APIChangesetUploadInputs(
            workspaceId: workspaceId,
            changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass,
            captureData: currentCaptureDataRecord,
            captureLocation: captureLocation,
            accessToken: accessToken,
            environment: userStateViewModel.selectedEnvironment
        )
        let apiChangesetUploadResults = try await apiChangesetUploadController.uploadFeatures(
            accessibilityFeatures: featuresToUpload,
            currentMappedFeaturesData: sharedAppData.currentMappedFeaturesData,
            inputs: apiChangesetUploadInputs
        )
        guard let mappedAccessibilityFeatures = apiChangesetUploadResults.accessibilityFeatures,
              let mappedElements = apiChangesetUploadResults.oswElements else {
            throw AnnotationViewError.apiChangesetUploadFailed(apiChangesetUploadResults)
        }
        sharedAppData.currentMappedFeaturesData.updateFeatures(mappedAccessibilityFeatures, for: accessibilityFeatureClass)
        sharedAppData.currentMappingData.updateFeatures(mappedElements, for: accessibilityFeatureClass)
        
        addFeaturesToCurrentDataset(
            captureImageData: currentCaptureDataRecord.imageData,
            featuresToUpload: featuresToUpload, mappedAccessibilityFeatures: mappedAccessibilityFeatures
        )
        
        sharedAppData.isUploadReady = true
        return apiChangesetUploadResults
    }
    
    private func addFeaturesToCurrentDataset(
        captureImageData: any CaptureImageDataProtocol,
        featuresToUpload: [any AccessibilityFeatureProtocol],
        mappedAccessibilityFeatures: [any AccessibilityFeatureProtocol]
    ) {
        Task {
            do {
                try sharedAppData.currentDatasetEncoder?.addFeatures(
                    features: featuresToUpload, frameNumber: captureImageData.id, timestamp: captureImageData.timestamp
                )
                try sharedAppData.currentDatasetEncoder?.addFeatures(
                    features: mappedAccessibilityFeatures, frameNumber: captureImageData.id, timestamp: captureImageData.timestamp
                )
            } catch {
                print("Error adding feature data to dataset encoder: \(error)")
            }
        }
    }
}

