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

struct ColorInfo {
    var color: SIMD4<Float> // Corresponds to the float4 in Metal
    var grayscale: Float    // Corresponds to the float in Metal
}

struct Params {
    var width: UInt32       // Corresponds to the uint in Metal
    var count: UInt32       // Corresponds to the uint in Metal
}

// TODO: Make this a class variable instead of a global variable
var annotationView: Bool = false

class SharedImageData: ObservableObject {
    @Published var cameraImage: UIImage?
//    @Published var objectSegmentation: CIImage?
//    @Published var segmentationImage: UIImage?
    @Published var pixelBuffer: CIImage?
    @Published var depthData: CVPixelBuffer?
//    @Published var depthDataImage: UIImage?
    @Published var segmentedIndices: [Int] = []
    @Published var classImages: [CIImage] = []
    
//    var updateSegmentation: ((Any) -> Void)?
    
}

struct ContentView: View {
    var selection: [Int]
    
    @StateObject private var sharedImageData = SharedImageData()
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    var objectLocation = ObjectLocation()
    
    var body: some View {
//        if (navigateToAnnotationView) {
//            AnnotationView(sharedImageData: sharedImageData, objectLocation: objectLocation, selection: sharedImageData.segmentedIndices, classes: Constants.ClassConstants.classes)
//        } else {
            VStack {
                if manager?.dataAvailable ?? false{
                    ZStack {
                        HostedCameraViewController(session: manager!.controller.captureSession)
                        HostedSegmentationViewController(sharedImageData: sharedImageData, selection: Array(selection), classes: Constants.ClassConstants.classes)
                    }
                    
                    NavigationLink(
                        destination: AnnotationView(sharedImageData: sharedImageData, objectLocation: objectLocation, selection: sharedImageData.segmentedIndices, classes: Constants.ClassConstants.classes),
                        isActive: $navigateToAnnotationView
                    ) {
                        Button {
                            annotationView = true
                            objectLocation.settingLocation()
                            manager!.startPhotoCapture()
                            // TODO: Instead of an arbitrary delay, we should have an event listener
                            // that triggers when the photo capture is completed
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
                }
                else {
                    VStack {
                        SpinnerView()
                        Text("Camera settings in progress")
                            .padding(.top, 20)
                    }
                }
            }
            .navigationBarTitle("Camera View", displayMode: .inline)
            .onAppear {
                if manager == nil {
                    manager = CameraManager(sharedImageData: sharedImageData)
//                    let segmentationController = SegmentationViewController(sharedImageData: sharedImageData)
//                    segmentationController.selection = selection
//                    segmentationController.classes = classes
//                    manager?.segmentationController = segmentationController
//                    
//                    sharedImageData.updateSegmentation = { index in
//                        self.manager?.segmentationController?.classSegmentationRequest()
//                    }
                }
            }
            .onDisappear {
                manager?.controller.stopStream()
            }
//        }
    }
}
