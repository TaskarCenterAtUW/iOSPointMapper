//
//  ContentView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    var selection: [Int]
    var classes: [String]
    
    @StateObject private var sharedImageData = SharedImageData()
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    
    var body: some View {
        if (navigateToAnnotationView) {
            AnnotationView(sharedImageData: sharedImageData)
        } else {
            VStack {
                if manager?.dataAvailable ?? false{
                    ZStack {
                        HostedCameraViewController(session: manager!.controller.captureSession)
                        HostedSegmentationViewController(sharedImageData: sharedImageData)
                    }
                    
                    NavigationLink(
                        destination: AnnotationView(sharedImageData: sharedImageData),
                        isActive: $navigateToAnnotationView
                    ) {
                        Button {
                            manager!.processingCapturedResult ? manager!.resumeStream() : manager!.startPhotoCapture()
                            navigateToAnnotationView = true
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
                }
            }
            .onDisappear {
                manager?.controller.stopStream()
            }
        }
    }
}

struct SpinnerView: View {
  var body: some View {
    ProgressView()
      .progressViewStyle(CircularProgressViewStyle(tint: .blue))
      .scaleEffect(2.0, anchor: .center) // Makes the spinner larger
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          // Simulates a delay in content loading
          // Perform transition to the next view here
        }
      }
  }
}

class SharedImageData: ObservableObject {
    @Published var cameraImage: UIImage?
    @Published var segmentationImage: UIImage?
}

class CameraViewController: UIViewController {
    var session: AVCaptureSession?
    var rootLayer: CALayer! = nil
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    
    init(session: AVCaptureSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUp(session: session!)
    }
    
    private func setUp(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 652.0)
//        previewLayer.borderWidth = 2.0
//        previewLayer.borderColor = UIColor.blue.cgColor
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
        }
    }
}

struct HostedCameraViewController: UIViewControllerRepresentable{
    var session: AVCaptureSession!
    
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController(session: session)
    }
    
    func updateUIViewController(_ uiView: CameraViewController, context: Context) {
    }
}

class SegmentationViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var segmentationView: UIImageView! = nil
    var sharedImageData: SharedImageData?
    
    static var requests = [VNRequest]()
    
    // define the filter that will convert the grayscale prediction to color image
    let masker = ColorMasker()
    
    init(sharedImageData: SharedImageData) {
        self.segmentationView = UIImageView()
        self.sharedImageData = sharedImageData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segmentationView.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 652.0)
//        segmentationView.layer.borderWidth = 2.0
//        segmentationView.layer.borderColor = UIColor.blue.cgColor
        segmentationView.contentMode = .scaleAspectFill
        self.view.addSubview(segmentationView)
        self.setupVisionModel()
    }
    
    private func setupVisionModel() {
        let modelURL = Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Can not load CNN model")
        }

        let segmentationRequest = VNCoreMLRequest(model: visionModel, completionHandler: {request, error in
            DispatchQueue.main.async(execute: {
                if let results = request.results {
                    self.processSegmentationRequest(results)
                }
            })
        })
        segmentationRequest.imageCropAndScaleOption = .scaleFill
        SegmentationViewController.requests = [segmentationRequest]
    }
    
    func processSegmentationRequest(_ observations: [Any]){
        let obs = observations as! [VNPixelBufferObservation]

        if obs.isEmpty{
            print("Empty")
        }

        let outPixelBuffer = (obs.first)!

        let segMaskGray = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)

        //pass through the filter that converts grayscale image to different shades of red
        self.masker.inputGrayImage = segMaskGray
        self.segmentationView.image = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .up)
        print("b")
        DispatchQueue.main.async {
            self.sharedImageData?.segmentationImage = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .up)
        }
    }
    
    //converts the Grayscale image to RGB
    // provides different shades of red based on pixel values
    class ColorMasker: CIFilter
    {
        var inputGrayImage : CIImage?
        
        let colormapKernel = CIColorKernel(source:
            "kernel vec4 colorMasker(__sample gray)" +
                "{" +
                " if (gray.r == 0.0f) {return vec4(0.0, 0.0, 0.0, 0.0);} else {" +
                "vec4 result;" +
                "result.r = 1;" +
                "result.g = gray.r;" +
                "result.b = gray.r;" +
                "result.a = 0.9;" +
                "return result;" +
            "}}"
        )
        
        override var attributes: [String : Any]
        {
            return [
                kCIAttributeFilterDisplayName: "Color masker",
                
                "inputGrayImage": [kCIAttributeIdentity: 0,
                                      kCIAttributeClass: "CIImage",
                                kCIAttributeDisplayName: "Grayscale Image",
                                       kCIAttributeType: kCIAttributeTypeImage
                                  ]
            ]
        }
        
        override var outputImage: CIImage!
        {
            guard let inputGrayImage = inputGrayImage,
                  let colormapKernel = colormapKernel else
            {
                return nil
            }
            
            let extent = inputGrayImage.extent
            let arguments = [inputGrayImage]
            
            return colormapKernel.apply(extent: extent, arguments: arguments)
        }
    }
}

struct HostedSegmentationViewController: UIViewControllerRepresentable{
    var sharedImageData: SharedImageData
    func makeUIViewController(context: Context) -> SegmentationViewController {
        return SegmentationViewController(sharedImageData: sharedImageData)
    }
    
    func updateUIViewController(_ uiView: SegmentationViewController, context: Context) {
    }
}

