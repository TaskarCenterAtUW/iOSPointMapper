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

enum ARContentViewConstants {
    enum Texts {
        static let contentViewTitle = "Camera View"
        
        static let cameraInProgressText = "Camera settings in progress"
    }
    
    enum Images {
        static let cameraIcon = "camera.circle.fill"
        
    }
    
    enum Colors {
        static let selectedClass = Color(red: 187/255, green: 134/255, blue: 252/255)
        static let unselectedClass = Color.white
    }
    
    enum Constraints {
        static let logoutIconSize: CGFloat = 20
    }
    
    enum Payload {
        static let isCameraStopped = "isStopped"
        static let cameraTransform = "cameraTransform"
        static let cameraIntrinsics = "cameraIntrinsics"
    }
}

struct ARContentView: View {
    var selection: [Int]
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @EnvironmentObject var segmentationPipeline: SegmentationARPipeline
    @EnvironmentObject var depthModel: DepthModel
    
    @StateObject var objectLocation = ObjectLocation()
    
    @State private var manager: ARCameraManager?
    @State private var navigateToAnnotationView = false
    
    var isCameraStoppedPayload = [ARContentViewConstants.Payload.isCameraStopped: true]
    
    // For deciding the layout
    private var isLandscape: Bool {
        CameraOrientation.isLandscapeOrientation(currentDeviceOrientation: manager?.deviceOrientation ?? .portrait)
    }
    
    var body: some View {
        Group {
            if manager?.dataAvailable ?? false {
                orientationStack {
                    HostedSegmentationViewController(
                        segmentationImage: Binding(
                            get: { manager?.cameraUIImage ?? UIImage() },
                            set: { manager?.cameraUIImage = $0 }
                    ))
                    HostedSegmentationViewController(segmentationImage: $segmentationPipeline.segmentationResultUIImage)
                    Button {
                        objectLocation.setLocationAndHeading()
                        manager?.stopStream()
                        segmentationPipeline.processFinalRequest(with: sharedImageData.cameraImage!, previousImage: nil,
                                                            additionalPayload: isCameraStoppedPayload)
                    } label: {
                        Image(systemName: ARContentViewConstants.Images.cameraIcon)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                    }
                }
            }
            else {
                VStack {
                    SpinnerView()
                    Text(ARContentViewConstants.Texts.cameraInProgressText)
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
        .navigationBarTitle(ARContentViewConstants.Texts.contentViewTitle, displayMode: .inline)
        .onAppear {
            navigateToAnnotationView = false
            
            if (manager == nil) {
                segmentationPipeline.setSelectionClasses(selection)
                segmentationPipeline.setCompletionHandler(segmentationPipelineCompletionHandler)
                manager = ARCameraManager(sharedImageData: sharedImageData, segmentationPipeline: segmentationPipeline)
            } else {
                manager?.resumeStream()
            }
        }
        .onDisappear {
            manager?.stopStream()
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isLandscape {
            HStack(content: content)
        } else {
            VStack(content: content)
        }
    }
    
    private func segmentationPipelineCompletionHandler(results: Result<SegmentationARPipelineResults, Error>) -> Void {
        switch results {
        case .success(let output):
            self.sharedImageData.segmentationLabelImage = output.segmentationImage
            self.sharedImageData.segmentedIndices = output.segmentedIndices
            self.sharedImageData.detectedObjectMap = output.detectedObjectMap
            self.sharedImageData.transformMatrixToPreviousFrame = output.transformMatrixFromPreviousFrame?.inverse
            
            let cameraTransform = output.additionalPayload[ARContentViewConstants.Payload.cameraTransform] as? simd_float4x4 ?? matrix_identity_float4x4
            self.sharedImageData.cameraTransform = cameraTransform
            let cameraIntrinsics = output.additionalPayload[ARContentViewConstants.Payload.cameraIntrinsics] as? simd_float3x3 ?? matrix_identity_float3x3
            self.sharedImageData.cameraIntrinsics = cameraIntrinsics
            
            if let isStopped = output.additionalPayload[ARContentViewConstants.Payload.isCameraStopped] as? Bool, isStopped {
                // Perform depth estimation only if LiDAR is not available
                if (!sharedImageData.isLidarAvailable) {
                    print("Performing depth estimation because LiDAR is not available.")
                    self.sharedImageData.depthImage = depthModel.performDepthEstimation(sharedImageData.cameraImage!)
                }
                self.navigateToAnnotationView = true
            } else {
                // Saving history
                self.sharedImageData.recordImageData(imageData: ImageData(
                    cameraImage: nil, depthImage: nil,
                    segmentationLabelImage: output.segmentationImage,
                    segmentedIndices: output.segmentedIndices, detectedObjectMap: output.detectedObjectMap,
                    cameraTransform: cameraTransform,
                    cameraIntrinsics: cameraIntrinsics,
                    transformMatrixToPreviousFrame: output.transformMatrixFromPreviousFrame?.inverse
                ))
            }
            return
        case .failure(let error):
//            fatalError("Unable to process segmentation \(error.localizedDescription)")
            print("Unable to process segmentation \(error.localizedDescription)")
            return
        }
    }
}
