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
    
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    // TODO: The fact that we are passing only one instance of objectLocation to AnnotationView
    //  means that the current setup is built to handle only one capture at a time.
    //  If we want to allow multiple captures, then we should to pass a different smaller object
    //  that only contains the device location details.
    //  There should be a separate class (possibly this ObjectLocation without the logic to get location details)
    //  that calculates the pixel-wise location using the device location and the depth map.
    var objectLocation = ObjectLocation()
    
    var body: some View {
        VStack {
            if manager?.dataAvailable ?? false{
                ZStack {
                    HostedCameraViewController(session: manager!.controller.captureSession,
                                               frameRect: VerticalFrame.getColumnFrame(
                                                width: UIScreen.main.bounds.width,
                                                height: UIScreen.main.bounds.height,
                                                row: 0)
                    )
                    HostedSegmentationViewController(segmentationImage: $segmentationModel.maskedSegmentationResults,
                                                     frameRect: VerticalFrame.getColumnFrame(
                                                        width: UIScreen.main.bounds.width,
                                                        height: UIScreen.main.bounds.height,
                                                        row: 1)
                    )
                }
                Button {
                    segmentationModel.performPerClassSegmentationRequest(with: sharedImageData.cameraImage!)
                    objectLocation.setLocationAndHeading()
                    manager?.stopStream()
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
        }
        .navigationDestination(isPresented: $navigateToAnnotationView) {
            AnnotationView(
                objectLocation: objectLocation,
                classes: Constants.ClassConstants.classes,
                selection: selection
            )
        }
        .navigationBarTitle("Camera View", displayMode: .inline)
        .onAppear {
            openChangeset()
            
            if (manager == nil) {
                segmentationModel.updateSegmentationRequest(selection: selection, completion: updateSharedImageSegmentation)
                segmentationModel.updatePerClassSegmentationRequest(selection: selection,
                                                                    completion: updatePerClassImageSegmentation)
                manager = CameraManager(sharedImageData: sharedImageData, segmentationModel: segmentationModel)
            } else {
                manager?.resumeStream()
            }
        }
        .onDisappear {
            manager?.stopStream()
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
    
    private func updatePerClassImageSegmentation(result: Result<PerClassSegmentationResultsOutput, Error>) -> Void {
        switch result {
        case .success(let output):
            self.sharedImageData.classImages = output.perClassSegmentationResults
            self.sharedImageData.segmentedIndices = output.segmentedIndices
            self.navigateToAnnotationView = true
            return
        case .failure(let error):
            fatalError("Unable to process per-class segmentation \(error.localizedDescription)")
        }
    }
    
    private func openChangeset() {
        print("open a changeset")
        ChangesetService.shared.openChangeset { result in
            switch result {
            case .success(let changesetId):
                print("Opened changeset with ID: \(changesetId)")
            case .failure(let error):
                print("Failed to open changeset: \(error.localizedDescription)")
            }
        }
    }
}
