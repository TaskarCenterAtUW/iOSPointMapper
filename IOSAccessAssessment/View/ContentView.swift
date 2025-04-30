//
//  ContentView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import AVFoundation
import Vision
import Metal
import CoreImage
import MetalKit

struct ContentView: View {
    var selection: [Int]
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @EnvironmentObject var segmentationModel: SegmentationModel
    @EnvironmentObject var segmentationPipeline: SegmentationPipeline
    @EnvironmentObject var depthModel: DepthModel
    
    @StateObject var objectLocation = ObjectLocation()
    
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    @State private var isChangesetOpened = false
    @State private var showRetryAlert = false
    @State private var retryMessage = ""
    
    var isCameraStoppedPayload = ["isStopped": true]
    
    var body: some View {
        VStack {
            if isChangesetOpened {
                if manager?.dataAvailable ?? false{
                    GeometryReader { geometry in
                        let isVertical = isStackVertical(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                        
                        if isVertical {
                            VStack {
                                mainView()
                            }
                        } else {
                            HStack {
                                mainView()
                            }
                        }
                    }
                }
                else {
                    VStack {
                        SpinnerView()
                        Text("Camera settings in progress")
                            .padding(.top, 20)
                    }
                }
            } else {
                SpinnerView()
                Text("Changeset opening in progress")
                    .padding(.top, 20)
            }
        }
        .navigationDestination(isPresented: $navigateToAnnotationView) {
            AnnotationView(
                selection: selection,
                objectLocation: objectLocation
            )
        }
        .navigationBarTitle("Camera View", displayMode: .inline)
        .onAppear {
            openChangeset()
            navigateToAnnotationView = false
            
            if (manager == nil) {
//                segmentationModel.updateSegmentationRequest(selection: selection, completion: updateSharedImageSegmentation)
//                segmentationModel.updatePerClassSegmentationRequest(selection: selection,
//                                                                    completion: updatePerClassImageSegmentation)
                segmentationPipeline.setSelectionClasses(selection)
                segmentationPipeline.setCompletionHandler(segmentationPipelineCompletionHandler)
                manager = CameraManager(sharedImageData: sharedImageData, segmentationModel: segmentationModel, segmentationPipeline: segmentationPipeline)
            } else {
                manager?.resumeStream()
            }
        }
        .onDisappear {
            manager?.stopStream()
        }
        .alert("Changeset opening error", isPresented: $showRetryAlert) {
            Button("Retry") {
                isChangesetOpened = false
                retryMessage = ""
                showRetryAlert = false
                
                openChangeset()
            }
        } message: {
            Text(retryMessage)
        }
    }
    
    @ViewBuilder
    private func mainView() -> some View {
        ZStack {
            HostedCameraViewController(session: manager!.controller.captureSession,
                                       frameRect: VerticalFrame.getColumnFrame(
                                        width: UIScreen.main.bounds.width,
                                        height: UIScreen.main.bounds.height,
                                        row: 0)
            )
            HostedSegmentationViewController(
                segmentationImage: $segmentationPipeline.segmentationResultUIImage,
                //                            segmentationImage: $segmentationModel.maskedSegmentationResults,
                frameRect: VerticalFrame.getColumnFrame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height,
                    row: 1)
            )
        }
        Button {
            //                        segmentationModel.performPerClassSegmentationRequest(with: sharedImageData.cameraImage!)
            objectLocation.setLocationAndHeading()
            manager?.stopStream()
            segmentationPipeline.processRequest(with: sharedImageData.cameraImage!, previousImage: nil,
                                                additionalPayload: isCameraStoppedPayload)
        } label: {
            Image(systemName: "camera.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.white)
        }
    }
    
    /**
     This function is used to determine if the stack will be horizontal or vertical
     */
    private func isStackVertical(screenWidth: CGFloat, screenHeight: CGFloat) -> Bool {
        print("Screen Width: \(screenWidth), Screen Height: \(screenHeight)")
        let inputWidth = Constants.ClassConstants.inputSize.width
        let inputHeight = Constants.ClassConstants.inputSize.height
        let inputAspectRatio = inputWidth / inputHeight
        
        let verticalFrameHeight = screenHeight / 2
        let verticalFrameWidth = verticalFrameHeight * inputAspectRatio
        let verticalFrameArea = verticalFrameWidth * verticalFrameHeight
        
        
        let horizontalFrameWidth = screenWidth / 2
        let horizontalFrameHeight = horizontalFrameWidth / inputAspectRatio
        let horizontalFrameArea = horizontalFrameWidth * horizontalFrameHeight
        
//        print("Vertical Frame Area: \(verticalFrameArea), Horizontal Frame Area: \(horizontalFrameArea)")
        return verticalFrameArea >= horizontalFrameArea
    }
        
        
    
    private func segmentationPipelineCompletionHandler(results: Result<SegmentationPipelineResults, Error>) -> Void {
        switch results {
        case .success(let output):
            self.sharedImageData.segmentationLabelImage = output.segmentationImage
            self.sharedImageData.segmentedIndices = output.segmentedIndices
            self.sharedImageData.objects = output.objects
//            print("Objects: ", output.objects.map { ($0.value.centroid, $0.value.isCurrent) })
            self.sharedImageData.appendFrame(frame: output.segmentationImage)
            if let isStopped = output.additionalPayload["isStopped"] as? Bool, isStopped {
                // Perform depth estimation only if LiDAR is not available
                if (!sharedImageData.isLidarAvailable) {
                    print("Performing depth estimation because LiDAR is not available.")
                    self.sharedImageData.depthImage = depthModel.performDepthEstimation(sharedImageData.cameraImage!)
                }
                self.navigateToAnnotationView = true
            }
            return
        case .failure(let error):
//            fatalError("Unable to process segmentation \(error.localizedDescription)")
            print("Unable to process segmentation \(error.localizedDescription)")
            return
        }
    }
    
    // Callbacks to the SegmentationModel
    private func updateSharedImageSegmentation(result: Result<SegmentationResultsOutput, Error>) -> Void {
        switch result {
        case .success(let output):
            self.sharedImageData.appendFrame(frame: output.segmentationResults)
            return
        case .failure(let error):
            fatalError("Unable to process segmentation \(error.localizedDescription)")
        }
    }
    
    // This function callback currently has control over navigation to the Annotation View.
    // This is not ideal behavior, this may be alleviated eventually when we use async/await
    // because at this moment, adding yet another callback to fix this would bloat the code.
    private func updatePerClassImageSegmentation(result: Result<PerClassSegmentationResultsOutput, Error>) -> Void {
        switch result {
        case .success(let output):
            // Prevent navigation to AnnotationView if the segmentation results are empty
            if (output.perClassSegmentationResults.count == 0) {
                return
            }
            self.sharedImageData.segmentationLabelImage = output.segmentationLabelResults
            self.sharedImageData.classImages = output.perClassSegmentationResults
            self.sharedImageData.segmentedIndices = output.segmentedIndices
            self.manager?.stopStream()
            // Perform depth estimation only if LiDAR is not available
            if (!sharedImageData.isLidarAvailable) {
                self.sharedImageData.depthImage = depthModel.performDepthEstimation(sharedImageData.cameraImage!)
            }
            self.navigateToAnnotationView = true
        case .failure(let error):
            fatalError("Unable to process per-class segmentation \(error.localizedDescription)")
        }
    }
    
    private func openChangeset() {
        ChangesetService.shared.openChangeset { result in
            switch result {
            case .success(let changesetId):
                print("Opened changeset with ID: \(changesetId)")
                isChangesetOpened = true
            case .failure(let error):
                retryMessage = "Failed to open changeset. Error: \(error.localizedDescription)"
                isChangesetOpened = false
                showRetryAlert = true
            }
        }
    }
}
