//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/10/25.
//

import SwiftUI
import CoreLocation
import simd

enum AnnotationViewConstants {
    enum Texts {
        static let annotationViewTitle = "Annotation"
        
        static let currentClassPrefixText = "Selected class: "
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
        }
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
    @Published var instances: [AccessibilityFeature] = []
    @Published var currentIndex: Int? = nil
    @Published var currentFeature: AccessibilityFeature? = nil
    
    func setInstances(_ instances: [AccessibilityFeature], currentClass: AccessibilityFeatureClass) throws {
        self.instances = instances
        if (currentClass.isWay) {
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
    
    func setCurrent(index: Int?, instances: [AccessibilityFeature], currentClass: AccessibilityFeatureClass) throws {
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

class AnnotationImageManagerStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    @Published var shouldDismiss: Bool = true
    
    func update(isFailed: Bool, errorMessage: String, shouldDismiss: Bool = true) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
        self.shouldDismiss = shouldDismiss
    }
}


struct AnnotationView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    let captureLocation: CLLocationCoordinate2D
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @Environment(\.dismiss) var dismiss
    
    @StateObject var manager: AnnotationImageManager = AnnotationImageManager()
    
    @StateObject var segmentationAnnontationPipeline: SegmentationAnnotationPipeline = SegmentationAnnotationPipeline()
    var attributeEstimationPipeline: AttributeEstimationPipeline = AttributeEstimationPipeline()
    
    let apiTransmissionController: APITransmissionController = APITransmissionController()
    
    @State private var managerStatusViewModel = AnnotationImageManagerStatusViewModel()
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait // To bind one-way with manager's orientation
    
    @StateObject var featureClassSelectionViewModel = AnnotationFeatureClassSelectionViewModel()
    @StateObject var featureSelectionViewModel = AnnotationFeatureSelectionViewModel()
    @State private var isShowingAnnotationFeatureDetailView: Bool = false
    
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
            handleOnInstanceChange()
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
                        isContainsAll: !currentClass.isWay
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
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        return (currentClassIndex >= 0 && currentClassIndex < segmentedClasses.count)
    }
    
    private func isCurrentIndexLast() -> Bool {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let currentClassIndex = featureClassSelectionViewModel.currentIndex else {
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        return currentClassIndex == segmentedClasses.count - 1
    }
    
    private func handleOnAppear() async {
        do {
            guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
                  let captureMeshData = currentCaptureDataRecord as? (any CaptureMeshDataProtocol) else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
            try segmentationAnnontationPipeline.configure()
            try attributeEstimationPipeline.configure(
                captureImageData: currentCaptureDataRecord, captureMeshData: captureMeshData
            )
            try manager.configure(
                selectedClasses: selectedClasses, segmentationAnnotationPipeline: segmentationAnnontationPipeline,
                captureImageData: currentCaptureDataRecord,
                captureMeshData: captureMeshData
            )
            let captureDataHistory = Array(await sharedAppData.captureDataQueue.snapshot())
            manager.setupAlignedSegmentationLabelImages(captureDataHistory: captureDataHistory)
            try featureClassSelectionViewModel.setCurrent(index: 0, classes: segmentedClasses)
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageDismissScreenSuffixKey)"
            )
        }
    }
    
    private func handleOnClassChange() {
        do {
            guard let currentClass = featureClassSelectionViewModel.currentClass else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            let accessibilityFeatures = try manager.updateFeatureClass(accessibilityFeatureClass: currentClass)
            try accessibilityFeatures.forEach { accessibilityFeature in
                accessibilityFeature.calculatedLocation = try attributeEstimationPipeline.processLocationRequest(
                    deviceLocation: captureLocation,
                    accessibilityFeature: accessibilityFeature
                )
            }
            featureClassSelectionViewModel.setOption(option: .classOption(.default))
            try featureSelectionViewModel.setInstances(accessibilityFeatures, currentClass: currentClass)
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageDismissScreenSuffixKey)"
            )
        }
    }
    
    private func handleOnInstanceChange() {
        do {
            try featureSelectionViewModel.setIndex(index: featureSelectionViewModel.currentIndex)
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageDismissScreenSuffixKey)")
        }
        do {
            guard let currentClass = featureClassSelectionViewModel.currentClass else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            var accessibilityFeatures: [AccessibilityFeature]
            if let currentFeature = featureSelectionViewModel.currentFeature {
                accessibilityFeatures = [currentFeature]
            } else {
                accessibilityFeatures = featureSelectionViewModel.instances
            }
            let isSelected = featureSelectionViewModel.currentFeature != nil
            try manager.updateFeature(
                accessibilityFeatureClass: currentClass,
                accessibilityFeatures: accessibilityFeatures,
                isSelected: isSelected
            )
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageDismissAlertSuffixKey)",
                shouldDismiss: false)
        }
    }
    
    private func confirmAnnotation() {
        if isCurrentIndexLast() {
            self.dismiss()
            return
        }
        do {
            guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
                  let currentClassIndex = featureClassSelectionViewModel.currentIndex else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
            try featureClassSelectionViewModel.setCurrent(index: currentClassIndex + 1, classes: segmentedClasses)
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageDismissScreenSuffixKey)"
            )
        }
    }
}
