//
//  AnnotationViewBase.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/10/25.
//

import SwiftUI
import Combine
import TipKit
import CoreLocation
import simd

enum AnnotationViewBaseConstants {
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
        static let apiChangesetUploadStatusAlertTitleKey = "Upload Error"
        static let apiChangesetUploadStatusAlertDismissButtonKey = "OK"
        static let apiChangesetUploadStatusAlertGenericMessageKey = "Failed to upload features. Press OK to dismiss this alert."
        static let apiChangesetUploadStatusAlertMessageSuffixKey = " feature(s) failed to upload. Press OK to dismiss this alert."
        
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

enum AnnotationViewBaseError: Error, LocalizedError {
    case classIndexOutofBounds
    case instanceIndexOutofBounds
    case invalidCaptureDataRecord
    case managerConfigurationFailed
    case authenticationError
    case workspaceConfigurationFailed
    case attributeEstimationFailed(Error)
    case uploadFailed
    
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
        }
    }
}

struct SelectFeatureInfoTipBase: Tip {
    
    var title: Text {
        Text(AnnotationViewBaseConstants.Texts.selectFeatureInfoTipTitle)
    }
    var message: Text? {
        Text(AnnotationViewBaseConstants.Texts.selectFeatureInfoTipMessage)
    }
    var image: Image? {
        Image(systemName: AnnotationViewBaseConstants.Images.infoIcon)
            .resizable()
    }
    var actions: [Action] {
        // Define a learn more button.
        Action(
            id: AnnotationViewBaseConstants.Texts.selectFeatureInfoTipLearnMoreButtonTitle,
            title: AnnotationViewBaseConstants.Texts.selectFeatureInfoTipLearnMoreButtonTitle
        )
    }
}

class AnnotationFeatureClassSelectionViewBaseModel: ObservableObject {
    @Published var currentIndex: Int? = nil
    @Published var currentClass: AccessibilityFeatureClass? = nil
    @Published var selectedAnnotationOption: AnnotationOption = .classOption(.default)
    
    func setCurrent(index: Int, classes: [AccessibilityFeatureClass]) throws {
        guard index < classes.count else {
            throw AnnotationViewBaseError.classIndexOutofBounds
        }
        self.currentIndex = index
        self.currentClass = classes[index]
    }
    
    func setOption(option: AnnotationOption) {
        self.selectedAnnotationOption = option
    }
}

class AnnotationFeatureSelectionViewBaseModel: ObservableObject {
    @Published var instances: [EditableAccessibilityFeature] = []
    @Published var currentIndex: Int? = nil
    @Published var currentFeature: EditableAccessibilityFeature? = nil
    
    func setInstances(_ instances: [EditableAccessibilityFeature], currentClass: AccessibilityFeatureClass) throws {
        self.instances = instances
        /// If the class is sidewalk, we always select the first instance, as there should be only one sidewalk instance.
        if (currentClass.kind == .sidewalk) {
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
            throw AnnotationViewBaseError.instanceIndexOutofBounds
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

class AnnotationViewStatusViewBaseModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    @Published var shouldDismiss: Bool = true
    
    init(shouldDismiss: Bool = true) {
        self.shouldDismiss = shouldDismiss
    }
    
    func update(isFailed: Bool, errorMessage: String, shouldDismiss: Bool = true) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
        self.shouldDismiss = shouldDismiss
    }
    
    func update(isFailed: Bool, error: Error, shouldDismiss: Bool = true) {
        self.isFailed = isFailed
        let dismissKey = shouldDismiss ?
        AnnotationViewBaseConstants.Texts.managerStatusAlertMessageDismissScreenSuffixKey :
        AnnotationViewBaseConstants.Texts.managerStatusAlertMessageDismissAlertSuffixKey
        self.errorMessage = "\(error.localizedDescription) \(dismissKey)"
        self.shouldDismiss = shouldDismiss
    }
}

public struct AnnotationViewBase: View {
    let selectedClasses: [AccessibilityFeatureClass]
    let captureLocation: CLLocationCoordinate2D
    
    @EnvironmentObject var sharedAppData: SharedBaseData
    @EnvironmentObject var sharedBaseContext: SharedBaseContext
    @Environment(\.dismiss) var dismiss
    
    @StateObject var manager: AnnotationImageManager = AnnotationImageManager()
    
    @StateObject var segmentationAnnontationPipeline: SegmentationAnnotationPipeline = SegmentationAnnotationPipeline()
    @StateObject var attributeEstimationPipeline: AttributeEstimationPipeline = AttributeEstimationPipeline()
    
    @StateObject private var managerStatusViewModel = AnnotationViewStatusViewBaseModel()
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait // To bind one-way with manager's orientation
    
    @StateObject var featureClassSelectionViewModel = AnnotationFeatureClassSelectionViewBaseModel()
    @StateObject var featureSelectionViewModel = AnnotationFeatureSelectionViewBaseModel()
    @State private var isShowingAnnotationFeatureDetailView: Bool = false
    
//    var selectFeatureInfoTipBase = SelectFeatureInfoTipBase()
    @State private var showSelectFeatureLearnMoreSheet = false
    
    public var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(AnnotationViewBaseConstants.Texts.annotationViewTitle)
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
                        Image(systemName: AnnotationViewBaseConstants.Images.closeIcon)
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
                AnnotationFeatureDetailViewBase(
                    accessibilityFeature: currentFeature,
                    title: "\(currentFeature.accessibilityFeatureClass.name.capitalized): \(currentFeatureIndex)"
                ) { feature in
                    EmptyView()
                }
                    .presentationDetents([.medium, .large])
            } else {
                Text(AnnotationViewBaseConstants.Texts.featureDetailNotAvailableText)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showSelectFeatureLearnMoreSheet) {
            SelectFeatureLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
        .alert(AnnotationViewBaseConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerStatusViewModel.isFailed, actions: {
            Button(AnnotationViewBaseConstants.Texts.managerStatusAlertDismissButtonKey) {
                let shouldDismiss = managerStatusViewModel.shouldDismiss
                managerStatusViewModel.update(isFailed: false, errorMessage: "")
                if shouldDismiss {
                    dismiss()
                }
            }
        }, message: {
            Text(managerStatusViewModel.errorMessage)
        })
    }
    
    private func loadingPageView() -> some View {
        VStack {
            Spacer()
            Text(AnnotationViewBaseConstants.Texts.loadingPageText)
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
                    Text("\(AnnotationViewBaseConstants.Texts.currentClassPrefixText): \(currentClass.name)")
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    CustomPicker (
                        label: AnnotationViewBaseConstants.Texts.selectObjectText,
                        selection: $featureSelectionViewModel.currentIndex,
                        isContainsAll: currentClass.kind != .sidewalk
                    ) {
                        ForEach(featureSelectionViewModel.instances.indices, id: \.self) { featureIndex in
                            Text("\(currentClass.name.capitalized): \(featureIndex)")
                                .tag(featureIndex as Int?)
                        }
                    }
                    Button(action: {
                        isShowingAnnotationFeatureDetailView = true
                    }) {
                        Image(systemName: AnnotationViewBaseConstants.Images.ellipsisIcon)
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
                            Image(systemName: AnnotationViewBaseConstants.Images.infoIcon)
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
                    Text(isCurrentIndexLast() ? AnnotationViewBaseConstants.Texts.finishText : AnnotationViewBaseConstants.Texts.nextText)
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
                throw AnnotationViewBaseError.invalidCaptureDataRecord
            }
            var captureMeshData: (any CaptureMeshDataProtocol)? = nil
            if sharedBaseContext.isEnhancedAnalysisEnabled {
                guard let captureMeshDataResults = currentCaptureDataRecord.meshData?.captureMeshDataResults else {
                    throw AnnotationViewBaseError.invalidCaptureDataRecord
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
                isEnhancedAnalysisEnabled: sharedBaseContext.isEnhancedAnalysisEnabled
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
                throw AnnotationViewBaseError.invalidCaptureDataRecord
            }
            let accessibilityFeatures = try manager.updateFeatureClass(accessibilityFeatureClass: currentClass)
            var lastEstimationError: Error? = nil
            accessibilityFeatures.forEach { accessibilityFeature in
                do {
                    try attributeEstimationPipeline.setPrerequisites(accessibilityFeature: accessibilityFeature)
                    try attributeEstimationPipeline.processLocationRequest(
                        deviceLocation: captureLocation,
                        accessibilityFeature: accessibilityFeature
                    )
                    try attributeEstimationPipeline.processAttributeRequest(
                        accessibilityFeature: accessibilityFeature
                    )
                    attributeEstimationPipeline.clearPrerequisites()
                } catch {
                    lastEstimationError = error
                }
            }
            featureClassSelectionViewModel.setOption(option: .classOption(.default))
            try featureSelectionViewModel.setInstances(accessibilityFeatures, currentClass: currentClass)
            if let lastEstimationError {
                throw AnnotationViewBaseError.attributeEstimationFailed(lastEstimationError)
            }
        } catch AnnotationViewBaseError.attributeEstimationFailed(let error) {
            managerStatusViewModel.update(
                isFailed: true, error: AnnotationViewBaseError.attributeEstimationFailed(error), shouldDismiss: false
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
                throw AnnotationViewBaseError.invalidCaptureDataRecord
            }
            var accessibilityFeatures: [EditableAccessibilityFeature]
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
                if currentClass.kind.attributes.contains(where: {
                    $0 == .width || $0 == .runningSlope || $0 == .crossSlope || $0 == .surfaceIntegrity
                }) {
                    let plane = try attributeEstimationPipeline.calculateAlignedPlane(
                        accessibilityFeature: currentFeature, worldPoints: nil
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
                try moveToNextClass()
            } catch AnnotationViewBaseError.classIndexOutofBounds {
                managerStatusViewModel.update(isFailed: true, error: AnnotationViewBaseError.classIndexOutofBounds)
            } catch {
                managerStatusViewModel.update(isFailed: true, error: error, shouldDismiss: false)
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
            throw AnnotationViewBaseError.invalidCaptureDataRecord
        }
        let segmentedClasses = currentCaptureDataRecord.imageData.captureImageDataResults.segmentedClasses
        try featureClassSelectionViewModel.setCurrent(index: currentClassIndex + 1, classes: segmentedClasses)
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
            Text(AnnotationViewBaseConstants.Texts.selectFeatureInfoLearnMoreSheetTitle)
                .font(.headline)
            Text(AnnotationViewBaseConstants.Texts.selectFeatureInfoLearnMoreSheetMessage)
                .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}
