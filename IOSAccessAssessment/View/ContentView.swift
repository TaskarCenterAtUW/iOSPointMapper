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

enum ContentViewConstants {
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
    }
}

struct ContentView: View {
    var selection: [Int]
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @EnvironmentObject var segmentationPipeline: SegmentationPipeline
    @EnvironmentObject var depthModel: DepthModel
    
    @StateObject var objectLocation = ObjectLocation()
    
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    
    var isCameraStoppedPayload = [ContentViewConstants.Payload.isCameraStopped: true]
    
    // For deciding the layout
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    private var isLandscape: Bool {
        CameraOrientation.isLandscapeOrientation(currentDeviceOrientation: manager?.deviceOrientation ?? .portrait)
//        horizontalSizeClass == .regular
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
                        segmentationPipeline.processRequest(with: sharedImageData.cameraImage!, previousImage: nil,
                                                            additionalPayload: isCameraStoppedPayload)
                    } label: {
                        Image(systemName: ContentViewConstants.Images.cameraIcon)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                    }
                }
            }
            else {
                VStack {
                    SpinnerView()
                    Text(ContentViewConstants.Texts.cameraInProgressText)
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
        .navigationBarTitle(ContentViewConstants.Texts.contentViewTitle, displayMode: .inline)
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
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isLandscape {
            HStack(content: content)
        } else {
            VStack(content: content)
        }
    }
    
    private func segmentationPipelineCompletionHandler(results: Result<SegmentationPipelineResults, Error>) -> Void {
        switch results {
        case .success(let output):
            self.sharedImageData.segmentationLabelImage = output.segmentationImage
            self.sharedImageData.segmentedIndices = output.segmentedIndices
            self.sharedImageData.detectedObjectMap = output.detectedObjectMap
            self.sharedImageData.transformMatrixToPreviousFrame = output.transformMatrixFromPreviousFrame?.inverse
            
            // Saving history
            self.sharedImageData.recordImageData(imageData: ImageData(
                cameraImage: nil, depthImage: nil,
                segmentationLabelImage: output.segmentationImage,
                segmentedIndices: output.segmentedIndices, detectedObjectMap: output.detectedObjectMap,
                transformMatrixToPreviousFrame: output.transformMatrixFromPreviousFrame?.inverse
            ))
//            self.sharedImageData.appendFrame(frame: output.segmentationImage)
            
            if let isStopped = output.additionalPayload[ContentViewConstants.Payload.isCameraStopped] as? Bool, isStopped {
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
