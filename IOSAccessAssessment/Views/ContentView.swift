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

class SharedImageData: ObservableObject {
    @Published var cameraImage: UIImage?
    @Published var depthData: CVPixelBuffer?
//    @Published var depthDataImage: UIImage?
    
    @Published var pixelBuffer: CIImage?
//    @Published var objectSegmentation: CIImage?
//    @Published var segmentationImage: UIImage?
    
    @Published var segmentedIndices: [Int] = []
    // Single segmentation image for each class
    @Published var classImages: [CIImage] = []
}

struct ContentView: View {
    var selection: [Int]
    
    @StateObject private var sharedImageData = SharedImageData()
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    // TODO: The fact that we are passing only one instance of objectLocation to AnnotationView
    //  means that the current setup is built to handle only one capture at a time.
    //  If we want to allow multiple captures, then we should to pass a different smaller object
    //  that only contains the device location details.
    //  There should be a separate class (possibly this ObjectLocation without the logic to get location details)
    //  that calculates the pixel-wise location using the device location and the depth map.
    var objectLocation = ObjectLocation()
    
    var screenAspectRatio: CGFloat = Constants.ClassConstants.inputSize.width / Constants.ClassConstants.inputSize.height
    
    var body: some View {
            VStack {
                if manager?.dataAvailable ?? false{
                        ZStack {
                            VStack {
                                HostedCameraViewController(session: manager!.controller.captureSession,
                                                           frameRect: VerticalFrame.getColumnFrame(
                                                            width: UIScreen.main.bounds.width,
                                                            height: UIScreen.main.bounds.height,
                                                            row: 0)
                                )
                                HostedSegmentationViewController(sharedImageData: sharedImageData,
                                                                 frameRect: VerticalFrame.getColumnFrame(
                                                                    width: UIScreen.main.bounds.width,
                                                                    height: UIScreen.main.bounds.height,
                                                                    row: 1),
                                    selection: Array(selection), classes: Constants.ClassConstants.classes
                                )
                            }
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
                AnnotationView(sharedImageData: sharedImageData,
                               objectLocation: objectLocation,
                               selection: sharedImageData.segmentedIndices,
                               classes: Constants.ClassConstants.classes,
                               selectedClassesIndices: selection
                )
            }
            .navigationBarTitle("Camera View", displayMode: .inline)
            .onAppear {
                if (manager == nil) {
                    manager = CameraManager(sharedImageData: sharedImageData)
                } else {
                    manager?.resumeStream()
                }
            }
            .onDisappear {
                manager?.stopStream()
            }
    }
}
