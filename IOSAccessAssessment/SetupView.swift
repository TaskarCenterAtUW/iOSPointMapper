//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Sai on 2/1/24.
//

import SwiftUI
import AVFoundation
import UIKit

struct SetupView: View {
    let classes = ["Background", "Aeroplane", "Bicycle", "Bird", "Boat", "Bottle", "Bus", "Car", "Cat", "Chair", "Cow", "Diningtable", "Dog", "Horse", "Motorbike", "Person", "Pottedplant", "Sheep", "Sofa", "Train", "TV"]
    @State private var selection = Set<Int>()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Setup View")
                    .font(.largeTitle)
                    .padding(.bottom, 5)
                
                Text("Select Classes to Identify")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                List {
                    ForEach(0..<classes.count, id: \.self) { index in
                        Button(action: {
                            if self.selection.contains(index) {
                                self.selection.remove(index)
                            } else {
                                self.selection.insert(index)
                            }
                        }) {
                            Text(classes[index])
                                .foregroundColor(self.selection.contains(index) ? .blue : .white)
                        }
                    }
                }
                .environment(\.colorScheme, .dark)
            }
            .padding()
            .navigationBarTitle("Setup View", displayMode: .inline)
            .navigationBarItems(trailing: NavigationLink(destination: CameraView(selection: Array(selection), classes: classes)) {
                Text("Next").foregroundStyle(Color.white).font(.headline)
            })
        }.environment(\.colorScheme, .dark)
    }
}

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isCaptureButtonDisabled = false
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCaptureButtonDisabled = false
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        capturedImage = image
    }
}

struct CameraView: View {
    var selection: [Int]
    var classes: [String]
    
    @ObservedObject var photoProcessor = PhotoCaptureProcessor()
    @State private var isUsingFrontCamera = false
    @State private var isShowingAnnotationView = false
    
    
    let session = AVCaptureSession()
    var body: some View {
    NavigationView {
        ZStack {
            if (isShowingAnnotationView) {
                AnnotationView(capImage: photoProcessor.capturedImage ?? UIImage(),
                capSeg: photoProcessor.capturedImage ?? UIImage(), classes: classes, selection: selection)
            } else {
                HostedViewController()
                    .edgesIgnoringSafeArea(.all)
                //let session: AVCaptureSession
                
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        VStack{
                            List {
                                Text("Selected:")
                                ForEach(selection, id: \.self) { index in
                                    Text("\(self.classes[index])")
                                }
                        } }
                        Spacer()
                        Button(action: {
                            self.toggleCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 20)
                        Button(action: {
                            self.capturePhoto()
                            isShowingAnnotationView = true
                        }) {
                            Image(systemName: "camera.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 20)
                        .disabled(photoProcessor.isCaptureButtonDisabled)
                    }
                }
                
                if let image = photoProcessor.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            isShowingAnnotationView = true
                            photoProcessor.capturedImage = nil
                        }
                }
            }
        }
        .onAppear {
//            self.setupCaptureSession()
//            self.session.startRunning()
        }
        .onDisappear {
//            self.session.stopRunning()
        }
    }
    .navigationBarTitle("Camera View", displayMode: .inline)
//    .navigationBarItems(trailing: NavigationLink(destination: CameraView(selection: Array(selection), classes: classes)) {
//        Text("Next").foregroundStyle(Color.white).font(.headline)
//    }) fix navigation bar to go to annotation view
}
    
    
    func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: isUsingFrontCamera ? .front : .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if self.session.canAddInput(input) {
            self.session.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(nil, queue: DispatchQueue(label: "cameraFrameQueue"))
        
        if self.session.canAddOutput(output) {
            self.session.addOutput(output)
        }
    }
    
    func capturePhoto() {
        guard let output = session.outputs.first as? AVCapturePhotoOutput else { return }

        let photoSettings = AVCapturePhotoSettings()
        output.capturePhoto(with: photoSettings, delegate: photoProcessor)
        photoProcessor.isCaptureButtonDisabled = true
    }
    
    func toggleCamera() {
            session.inputs.forEach { input in
                session.removeInput(input)
            }
            isUsingFrontCamera.toggle()
            setupCaptureSession()
    }
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var permissionGranted = false
    
    private let session = AVCaptureSession()
    private let videoDataOutputQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
//    var detectionLayer: CALayer! = nil
    var detectionView: UIImageView! = nil
    var screenRect: CGRect! = nil
    
//    private var requests = [VNRequest]()
    
    //For semantic segmentation
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
//    //define the filter that will convert the grayscale prediction to color image
//    let masker = ColorMasker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermission()
        
        videoDataOutputQueue.async { [unowned self] in
            guard permissionGranted else { return }
            // Do any additional setup after loading the view, typically from a nib.
            self.setupAVCapture()
            
//            //setup vision parts
//            self.setupVisionModel()
            
            //start the capture
            self.session.startRunning()
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            
        case .notDetermined:
            requestPermission()
            
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        videoDataOutputQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { [unowned self] granted in
            self.permissionGranted = granted
            self.videoDataOutputQueue.resume()
        })
    }
    
    func setupAVCapture() {
        //select a video device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        session.beginConfiguration()
        //video format
        session.sessionPreset = .vga640x480
        
        //add video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        
        session.addInput(deviceInput)
        
        //add video output
        guard session.canAddOutput(videoDataOutput) else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        
        session.addOutput(videoDataOutput)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        let captureConnection = videoDataOutput.connection(with: .video)
        //always process the frames
        captureConnection?.isEnabled = true
        
        session.commitConfiguration()
        
        // Preview layer
        screenRect = UIScreen.main.bounds
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
        previewLayer.frame = CGRect(x: 0, y: 0, width: 400, height: 850)
//        previewLayer.borderWidth = 2.0
//        previewLayer.borderColor = UIColor.blue.cgColor
        
//        detectionView = UIImageView()
//        detectionView.frame = CGRect(x: 59, y: 366, width: 256, height: 256)
//        detectionView.transform = CGAffineTransform(rotationAngle: -.pi / 2)
//        detectionView.layer.borderWidth = 2.0
//        detectionView.layer.borderColor = UIColor.blue.cgColor
        
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
//            self!.view.addSubview(self!.detectionView)
        }
    }
    
//    func setupVisionModel() {
//        let modelURL = Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc")
//        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
//            fatalError("Can not load CNN model")
//        }
//
//        let segmentationRequest = VNCoreMLRequest(model: visionModel, completionHandler: {request, error in
//            DispatchQueue.main.async(execute: {
//                if let results = request.results {
//                    self.processSegmentationRequest(results)
//                }
//            })
//        })
//        segmentationRequest.imageCropAndScaleOption = .scaleFill
//        self.requests = [segmentationRequest]
//    }
//
//    func processSegmentationRequest(_ observations: [Any]){
//        let obs = observations as! [VNPixelBufferObservation]
//
//        if obs.isEmpty{
//            print("Empty")
//        }
//
//        let outPixelBuffer = (obs.first)!
//
//        let segMaskGray = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
//
//        //pass through the filter that converts grayscale image to different shades of red
//        self.masker.inputGrayImage = segMaskGray
//
//        self.view.addSubview(detectionView)
//        self.detectionView.image = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .right)
////        }
//    }
    
//    // this function notifies AVCatpreuDelegate everytime a new frame is received
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
//
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
//
//        do {
//            try imageRequestHandler.perform(self.requests)
//        } catch{
//            print(error)
//        }
//    }
}

struct HostedViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        return ViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}



struct AnnotationView: View {
    @State private var index = 0
    @State private var selectedIndex: Int? = nil
    @State private var responses = [Int]()
    let options = ["I agree with this class annotation", "Annotation is missing some instances of the class", "The class annotation is misidentified"]
    
    var capImage: UIImage
    var capSeg: UIImage
    var classes: [String]
    var selection: [Int]
    
    var body: some View {
    NavigationView {
        VStack {
            HStack {
                Spacer()
                Image(uiImage: capImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                Spacer()
            }
            
            HStack {
                Spacer()
                Text("Selected class: \(classes[selection[index]])")
                Spacer()
            }
            
            ProgressBar(value: calculateProgress(), total: selection.count)
            
            HStack {
                Spacer()
                VStack {
                    ForEach(0..<options.count) { index in
                        Button(action: {
                            // Toggle selection
                            if selectedIndex == index {
                                selectedIndex = nil
                            } else {
                                selectedIndex = index
                            }
                        }) {
                            Text(options[index])
                                .padding()
                                .foregroundColor(selectedIndex == index ? .red : .blue) // Change color based on selection
                        }
                    }
                }
                Spacer()
            }
            
            Button(action: {
                self.nextSegment()
                selectedIndex = nil
            }) {
                Text("Next")
            }
            .padding()
        }
    }
    .navigationBarTitle("Annotation View", displayMode: .inline)
  }
    
    func selectOption(option: Int) {
        responses.append(option)
    }
    
    func nextSegment() {
        index += 1
        if index >= selection.count {
            // Handle completion, save responses, or navigate to the next screen
        }
    }
    
    func calculateProgress() -> Float {
        return Float(index + 1) / Float(selection.count)
    }
}

struct ProgressBar: View {
    var value: Float
    var total: Int
    
    var body: some View {
        ProgressView(value: value, total: Float(total))
            .progressViewStyle(LinearProgressViewStyle())
            .padding()
    }
}






//struct AnnotationView: View {
//    @State private var index = 0
//    @State private var responses = [Int]()
//
//    let capImage: UIImage
//    let capSeg: UIImage
//    let classes: [String]
//    let selection: [Int]
//
//    var body: some View {
//        VStack {
//            VStack {
//                HStack {
//
//                    Image(uiImage: capImage)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(height: 200)
//                    Image(uiImage: capSeg)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(height: 200)
//                }
//                .padding()
//
//                HStack {
//                    ForEach(0..<3) { responseIndex in
//                        Button(action: {
//                            self.selectionClicked(responseIndex)
//                        }) {
//                            Text(self.classes[self.selection[responseIndex]])
//                                .padding()
//                                .foregroundColor(responses[index] == responseIndex ? .red : .blue)
//                        }
//                    }
//                }
//                .padding()
//
//                Button(action: {
//                    self.onClickNext()
//                }) {
//                    Text("Next")
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(8)
//                }
//                .padding(.top)
//
//                ProgressBar(progress: Double(index + 1) / Double(selection.count))
//                    .padding()
//            }
//        }
//        .navigationBarTitle("Annotation View", displayMode: .inline)
//    }
//
//    private func selectionClicked(_ index: Int) {
//        responses.append(index)
//        self.index += 1
//    }
//
//    private func onClickNext() {
//        if index == selection.count {
//            // Handle moving to the next view or action
//        } else {
//            // Reset buttons
//            responses.append(-1)
//            index += 1
//        }
//    }
//}
//
//struct ProgressBar: View {
//    var progress: Double
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack(alignment: .leading) {
//                Rectangle()
//                    .foregroundColor(Color.secondary)
//                    .frame(width: geometry.size.width, height: 10)
//
//                Rectangle()
//                    .foregroundColor(Color.blue)
//                    .frame(width: CGFloat(self.progress) * geometry.size.width, height: 10)
//                    .animation(.linear)
//            }
//        }
//    }
//}





#Preview {
    SetupView()
}
