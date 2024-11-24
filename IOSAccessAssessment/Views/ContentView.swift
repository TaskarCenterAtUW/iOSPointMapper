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
                        HostedSegmentationViewController(segmentationImage: $segmentationModel.segmentationResults,
                                                         frameRect: VerticalFrame.getColumnFrame(
                                                            width: UIScreen.main.bounds.width,
                                                            height: UIScreen.main.bounds.height,
                                                            row: 1)
                        )
                    }
                    Button {
                        objectLocation.setLocationAndHeading()
                        manager?.stopStream()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            navigateToAnnotationView = true
                        }
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
                AnnotationView(objectLocation: objectLocation,
                               classes: Constants.ClassConstants.classes,
                               selection: selection
                )
            }
            .navigationBarTitle("Camera View", displayMode: .inline)
            .onAppear {
                if (manager == nil) {
                    segmentationModel.updateSegmentationRequest(selection: selection, completion: updateSharedImageSegmentation)
                    segmentationModel.updatePerClassSegmentationRequest(selection: selection)
                    manager = CameraManager(sharedImageData: sharedImageData, segmentationModel: segmentationModel)
                } else {
                    manager?.resumeStream()
                }
            }
            .onDisappear {
                manager?.stopStream()
            }
    }
    
    private func updateSharedImageSegmentation(result: Result<UIImage, Error>) -> Void {
        switch result {
        case .success(let segmentationResult):
            return
        case .failure(let error):
            fatalError("Unable to process segmentation \(error.localizedDescription)")
        }
    }
}
