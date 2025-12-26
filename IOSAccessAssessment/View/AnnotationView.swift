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

enum AnnotationViewConstants {
    enum Texts {
        static let annotationViewTitle = "Annotation"
        
        static let currentClassPrefixText = "Selected class"
        static let finishText = "Finish"
        static let nextText = "Next"
        
        static let selectObjectText = "Select an object"
        
        static let loadingPageText = "Loading. Please wait..."
        
        /// Feature Detail View Text
        static let featureDetailViewTitle = "Feature Details"
        static let featureDetailViewIdKey = "ID"
        static let featureDetailViewLocationKey = "Location"
        static let featureDetailNotAvailableText = "Not Available"
        
        /// Alert texts
        static let managerStatusAlertTitleKey = "Error"
        static let managerStatusAlertDismissButtonKey = "OK"
        static let managerStatusAlertMessageDismissScreenSuffixKey = "Press OK to close this screen."
        static let managerStatusAlertMessageDismissAlertSuffixKey = "Press OK to dismiss this alert."
        static let apiTransmissionStatusAlertTitleKey = "Upload Error"
        static let apiTransmissionStatusAlertDismissButtonKey = "OK"
        static let apiTransmissionStatusAlertGenericMessageKey = "Failed to upload features. Press OK to dismiss this alert."
        static let apiTransmissionStatusAlertMessageSuffixKey = " feature(s) failed to upload. Press OK to dismiss this alert."
        
        /// SelectObjectInfoTip
        static let selectFeatureInfoTipTitle = "Select a Feature"
        static let selectFeatureInfoTipMessage = "Please select the individual feature that you want to annotate"
        static let selectFeatureInfoTipLearnMoreButtonTitle = "Learn More"
        
        /// SelectObjectInfoLearnMoreSheetView
        static let selectFeatureInfoLearnMoreSheetTitle = "Annotating an Individual Feature"
        static let selectFeatureInfoLearnMoreSheetMessage = """
        For each type of accessibility feature, the app can identify multiple feature instances within the same image. 
        
        **Select All**: Default option. You can annotate all features of a particular type together.
        
        **Individual**: You can select a particular feature from the dropdown menu if you wish to provide specific annotations for an individual feature.
        
        **Ellipsis [...]**: For each feature, you can also view its details by tapping the ellipsis button next to the dropdown menu.
        """
    }
    
    enum Images {
        static let checkIcon = "checkmark"
        static let ellipsisIcon = "ellipsis"
        static let infoIcon = "info.circle"
        static let closeIcon = "xmark"
        static let errorIcon = "exclamationmark.triangle"
    }
}

enum AnnotationViewError: Error, LocalizedError {
    case classIndexOutofBounds
    case instanceIndexOutofBounds
    case invalidCaptureDataRecord
    case managerConfigurationFailed
    case authenticationError
    case workspaceConfigurationFailed
    case attributeEstimationFailed(Error)
    case uploadFailed
    case apiTransmissionFailed(APITransmissionResults)
    
    var errorDescription: String? {
        switch self {
        case .classIndexOutofBounds:
            return "The Current Class is not in the list."
        case .instanceIndexOutofBounds:
            return "Exceeded the number of instances for the current class."
        case .invalidCaptureDataRecord:
            return "The Current Capture is invalid."
        case .managerConfigurationFailed:
            return "Annotation Configuration failed"
        case .authenticationError:
            return "Authentication error. Please log in again."
        case .workspaceConfigurationFailed:
            return "Workspace configuration failed. Please check your workspace settings."
        case .attributeEstimationFailed(let error):
            return "Some Attribute Estimation calculations failed. They may be ignored. \nError: \(error.localizedDescription)"
        case .uploadFailed:
            return "Failed to upload annotations."
        case .apiTransmissionFailed(let results):
            return "API Transmission failed with \(results.failedFeatureUploads) failed uploads."
        }
    }
}

struct SelectFeatureInfoTip: Tip {
    
    var title: Text {
        Text(AnnotationViewConstants.Texts.selectFeatureInfoTipTitle)
    }
    var message: Text? {
        Text(AnnotationViewConstants.Texts.selectFeatureInfoTipMessage)
    }
    var image: Image? {
        Image(systemName: AnnotationViewConstants.Images.infoIcon)
            .resizable()
    }
    var actions: [Action] {
        // Define a learn more button.
        Action(
            id: AnnotationViewConstants.Texts.selectFeatureInfoTipLearnMoreButtonTitle,
            title: AnnotationViewConstants.Texts.selectFeatureInfoTipLearnMoreButtonTitle
        )
    }
}

class AnnotationFeatureClassSelectionViewModel: ObservableObject {
    @Published var currentIndex: Int? = nil
    @Published var currentClass: AccessibilityFeatureClass? = nil
    @Published var selectedAnnotationOption: AnnotationOption = .classOption(.default)
    
    func setCurrent(index: Int, classes: [AccessibilityFeatureClass]) throws {
        guard index < classes.count else {
            throw AnnotationViewError.classIndexOutofBounds
        }
        self.currentIndex = index
        self.currentClass = classes[index]
    }
    
    func setOption(option: AnnotationOption) {
        self.selectedAnnotationOption = option
    }
}

class AnnotationFeatureSelectionViewModel: ObservableObject {
    @Published var instances: [EditableAccessibilityFeature] = []
    @Published var currentIndex: Int? = nil
    @Published var currentFeature: EditableAccessibilityFeature? = nil
    
    func setInstances(_ instances: [EditableAccessibilityFeature], currentClass: AccessibilityFeatureClass) throws {
        self.instances = instances
        /// If the class is sidewalk, we always select the first instance, as there should be only one sidewalk instance.
        if (currentClass.oswPolicy.oswElementClass == .Sidewalk) {
            try setIndex(index: 0)
        } else {
            try setIndex(index: nil)
        }
    }
    
    func setIndex(index: Int?) throws {
        guard let index = index else {
            self.currentIndex = nil
            self.currentFeature = nil
            return
        }
        guard index < instances.count else {
            throw AnnotationViewError.instanceIndexOutofBounds
        }
        self.currentIndex = index
        self.currentFeature = instances[index]
    }
    
    func setCurrent(index: Int?, instances: [EditableAccessibilityFeature], currentClass: AccessibilityFeatureClass) throws {
        try setInstances(instances, currentClass: currentClass)
        try setIndex(index: index)
    }
    
    func setOptionOnFeature(option: AnnotationOption) {
        if let currentFeature = self.currentFeature {
            objectWillChange.send()
            currentFeature.setAnnotationOption(option)
        }
    }
}

class AnnotationViewStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    @Published var shouldDismiss: Bool = true
    
    func update(isFailed: Bool, errorMessage: String, shouldDismiss: Bool = true) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
        self.shouldDismiss = shouldDismiss
    }
    
    func update(isFailed: Bool, error: Error, shouldDismiss: Bool = true) {
        self.isFailed = isFailed
        let dismissKey = shouldDismiss ?
        AnnotationViewConstants.Texts.managerStatusAlertMessageDismissScreenSuffixKey :
        AnnotationViewConstants.Texts.managerStatusAlertMessageDismissAlertSuffixKey
        self.errorMessage = "\(error.localizedDescription) \(dismissKey)"
        self.shouldDismiss = shouldDismiss
    }
}

class APITransmissionStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    
    func update(isFailed: Bool, errorMessage: String) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
    }
    
    func update(apiTransmissionResults: APITransmissionResults) {
        let failedFeatureUploads = apiTransmissionResults.failedFeatureUploads
        if failedFeatureUploads == 0 {
            self.isFailed = true
            self.errorMessage = "Unknown Error Occurred."
        } else {
            self.isFailed = true
            self.errorMessage = "\(failedFeatureUploads) \(AnnotationViewConstants.Texts.apiTransmissionStatusAlertMessageSuffixKey)"
        }
    }
}

struct AnnotationView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    let captureLocation: CLLocationCoordinate2D
    
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject var sharedAppData: SharedAppData
    @Environment(\.dismiss) var dismiss
    
    @StateObject var manager: AnnotationImageManager = AnnotationImageManager()
    
    @StateObject var segmentationAnnontationPipeline: SegmentationAnnotationPipeline = SegmentationAnnotationPipeline()
    @StateObject var attributeEstimationPipeline: AttributeEstimationPipeline = AttributeEstimationPipeline()
    
    let apiTransmissionController: APITransmissionController = APITransmissionController()
    
    @StateObject private var managerStatusViewModel = AnnotationViewStatusViewModel()
    @StateObject private var apiTransmissionStatusViewModel = APITransmissionStatusViewModel()
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
        .alert(AnnotationViewConstants.Texts.apiTransmissionStatusAlertTitleKey,
               isPresented: $apiTransmissionStatusViewModel.isFailed, actions: {
            Button(AnnotationViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                apiTransmissionStatusViewModel.update(isFailed: false, errorMessage: "")
                do {
                    try moveToNextClass()
                } catch {
                    managerStatusViewModel.update(isFailed: true, error: error)
                }
            }
        }, message: {
            Text(apiTransmissionStatusViewModel.errorMessage)
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
            HostedAnnotationImageViewController(annotationImageManager: manager)
            
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
                        isContainsAll: currentClass.oswPolicy.oswElementClass != .Sidewalk
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
                captureImageData: currentCaptureDataRecord.imageData
                /// TODO: MESH PROCESSING: Enable mesh data processing
                , captureMeshData: captureMeshData
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
                do {
                    try attributeEstimationPipeline.processLocationRequest(
                        deviceLocation: captureLocation,
                        accessibilityFeature: accessibilityFeature
                    )
                    try attributeEstimationPipeline.processAttributeRequest(accessibilityFeature: accessibilityFeature)
                } catch {
                    lastEstimationError = error
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
            var accessibilityFeatures: [EditableAccessibilityFeature]
            var featureSelectedStatus: [UUID: Bool] = [:]
            if let currentFeature = featureSelectionViewModel.currentFeature {
                accessibilityFeatures = [currentFeature]
                featureSelectedStatus[currentFeature.id] = true /// Selected and highlighted
                if let oldIndex = oldIndex, oldIndex != featureSelectionViewModel.currentIndex,
                   oldIndex >= 0, oldIndex < featureSelectionViewModel.instances.count {
                    let oldFeature = featureSelectionViewModel.instances[oldIndex]
                    accessibilityFeatures.append(oldFeature)
                    featureSelectedStatus[oldFeature.id] = false /// Selected, but not highlighted
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
                featureSelectedStatus: featureSelectedStatus
            )
        } catch {
            managerStatusViewModel.update(isFailed: true, error: error, shouldDismiss: false)
        }
    }
    
    private func confirmAnnotation() {
        Task {
            do {
                let apiTransmissionResults = try await uploadFeatures()
                if let apiTransmissionResults, apiTransmissionResults.failedFeatureUploads > 0 {
                    throw AnnotationViewError.apiTransmissionFailed(apiTransmissionResults)
                }
                try moveToNextClass()
            } catch AnnotationViewError.classIndexOutofBounds {
                managerStatusViewModel.update(isFailed: true, error: AnnotationViewError.classIndexOutofBounds)
            } catch AnnotationViewError.apiTransmissionFailed(let results) {
                apiTransmissionStatusViewModel.update(apiTransmissionResults: results)
            } catch {
                apiTransmissionStatusViewModel.update(
                    isFailed: true,
                    errorMessage: AnnotationViewConstants.Texts.apiTransmissionStatusAlertGenericMessageKey
                )
            }
        }
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
    
    private func uploadFeatures() async throws -> APITransmissionResults? {
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
        let featuresToUpload: [any AccessibilityFeatureProtocol] = featureSelectionViewModel.instances.filter { feature in
            feature.selectedAnnotationOption != .individualOption(.discard) &&
            feature.accessibilityFeatureClass == accessibilityFeatureClass
        }
        guard !featuresToUpload.isEmpty else {
            return nil
        }
        let apiTransmissionResults = try await apiTransmissionController.uploadFeatures(
            workspaceId: workspaceId,
            changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass,
            accessibilityFeatures: featuresToUpload,
            captureData: currentCaptureDataRecord,
            captureLocation: captureLocation,
            mappingData: sharedAppData.mappingData,
            accessToken: accessToken
        )
        guard let mappedAccessibilityFeatures = apiTransmissionResults.accessibilityFeatures else {
            throw AnnotationViewError.apiTransmissionFailed(apiTransmissionResults)
        }
        sharedAppData.mappingData.updateFeatures(mappedAccessibilityFeatures, for: accessibilityFeatureClass)
        print("Mapping Data: \(sharedAppData.mappingData)")
        
        addFeaturesToCurrentDataset(
            captureImageData: currentCaptureDataRecord.imageData,
            featuresToUpload: featuresToUpload, mappedAccessibilityFeatures: mappedAccessibilityFeatures
        )
        
        sharedAppData.isUploadReady = true
        return apiTransmissionResults
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

struct SelectFeatureLearnMoreSheetView: View {
    @Environment(\.dismiss)
    var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            //            Image(systemName: "number")
            //                .resizable()
            //                .scaledToFit()
            //                .frame(width: 160)
            //                .foregroundStyle(.accentColor)
            Text(AnnotationViewConstants.Texts.selectFeatureInfoLearnMoreSheetTitle)
                .font(.headline)
            Text(AnnotationViewConstants.Texts.selectFeatureInfoLearnMoreSheetMessage)
                .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}
