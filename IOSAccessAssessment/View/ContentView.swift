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
    @EnvironmentObject var segmentationPipeline: SegmentationPipeline
    @EnvironmentObject var depthModel: DepthModel
    
    @StateObject var objectLocation = ObjectLocation()
    
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    
    var isCameraStoppedPayload = ["isStopped": true]
    
    var body: some View {
        VStack {
            if manager?.dataAvailable ?? false{
                ZStack {
//                        HostedCameraViewController(session: manager!.controller.captureSession,
//                                                   frameRect: VerticalFrame.getColumnFrame(
//                                                    width: UIScreen.main.bounds.width,
//                                                    height: UIScreen.main.bounds.height,
//                                                    row: 0)
//                        )
                    HostedSegmentationViewController(
                        segmentationImage: $segmentationPipeline.segmentationResultUIImage,
                                                     frameRect: VerticalFrame.getColumnFrame(
                                                        width: UIScreen.main.bounds.width,
                                                        height: UIScreen.main.bounds.height,
                                                        row: 1)
                    )
                    HostedSegmentationViewController(
                        segmentationImage: Binding(
                            get: { manager?.cameraUIImage ?? UIImage() },
                            set: { manager?.cameraUIImage = $0 }
                        ),
                                                     frameRect: VerticalFrame.getColumnFrame(
                                                        width: UIScreen.main.bounds.width,
                                                        height: UIScreen.main.bounds.height,
                                                        row: 0)
                    )
                }
                Button {
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
                selection: selection,
                objectLocation: objectLocation
            )
        }
        .navigationBarTitle("Camera View", displayMode: .inline)
        .onAppear {
            navigateToAnnotationView = false
            
            if (manager == nil) {
                segmentationPipeline.setSelectionClasses(selection)
                segmentationPipeline.setCompletionHandler(segmentationPipelineCompletionHandler)
                manager = CameraManager(sharedImageData: sharedImageData, segmentationPipeline: segmentationPipeline)
            } else {
                manager?.resumeStream()
            }
        }
        .onDisappear {
            manager?.stopStream()
        }
    }
    
    private func segmentationPipelineCompletionHandler(results: Result<SegmentationPipelineResults, Error>) -> Void {
        switch results {
        case .success(let output):
            self.sharedImageData.segmentationLabelImage = output.segmentationImage
            self.sharedImageData.segmentedIndices = output.segmentedIndices
            self.sharedImageData.detectedObjects = output.detectedObjects
            self.sharedImageData.transformMatrixToPreviousFrame = output.transformMatrix?.inverse
//            print("Objects: ", output.objects.map { ($0.value.centroid, $0.value.isCurrent) })
            
            // Saving history
            self.sharedImageData.recordImageData(imageData: ImageData(
                cameraImage: nil, depthImage: nil,
                segmentationLabelImage: output.segmentationImage,
                segmentedIndices: output.segmentedIndices, detectedObjects: output.detectedObjects,
                transformMatrixToPreviousFrame: output.transformMatrix?.inverse
            ))
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
}
