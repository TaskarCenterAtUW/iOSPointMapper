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
    
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    @State private var isChangesetOpened = false
    @State private var showRetryAlert = false
    @State private var retryMessage = ""
    
    // TODO: The fact that we are passing only one instance of objectLocation to AnnotationView
    //  means that the current setup is built to handle only one capture at a time.
    //  If we want to allow multiple captures, then we should to pass a different smaller object
    //  that only contains the device location details.
    //  There should be a separate class (possibly this ObjectLocation without the logic to get location details)
    //  that calculates the pixel-wise location using the device location and the depth map.
    var objectLocation = ObjectLocation()
    
    var body: some View {
        VStack {
            if isChangesetOpened {
                if manager?.dataAvailable ?? false{
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
                        segmentationModel.performPerClassSegmentationRequest(with: sharedImageData.cameraImage!)
                        objectLocation.setLocationAndHeading()
//                        manager?.stopStream() // To be done in the performPerClassSegmentationRequest callback
                    } label: {
                        Image(systemName: "camera.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
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
                objectLocation: objectLocation,
                classes: Constants.ClassConstants.classNames,
                selection: selection
            )
        }
        .navigationBarTitle("Camera View", displayMode: .inline)
        .onAppear {
            openChangeset()
            navigateToAnnotationView = false
            
            if (manager == nil) {
                segmentationModel.updateSegmentationRequest(selection: selection, completion: updateSharedImageSegmentation)
                segmentationModel.updatePerClassSegmentationRequest(selection: selection,
                                                                    completion: updatePerClassImageSegmentation)
                segmentationPipeline.setSelectionClassLabels(selection.map { Constants.ClassConstants.labels[$0] })
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
