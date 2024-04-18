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


let grayscaleToClassMap: [UInt8: String] = [
    12: "Background",
    36: "Aeroplane",
    48: "Bicycle",
    84: "Bird",
    96: "Boat",
    108: "Bottle",
    132: "Bus",
    144: "Car",
    180: "Cat",
    216: "Chair",
    228: "Cow",
    240: "Diningtable"
]

let grayValues: [Float] = [12, 36, 48, 84, 96, 108, 132, 144, 180, 216, 228, 240].map{Float($0)/255.0}

let colors: [CIColor] = [
    CIColor(red: 1.0, green: 0.0, blue: 0.0),      // Red
    CIColor(red: 0.0, green: 1.0, blue: 0.0),      // Green
    CIColor(red: 0.0, green: 0.0, blue: 1.0),      // Blue
    CIColor(red: 0.5, green: 0.0, blue: 0.5),      // Purple
    CIColor(red: 1.0, green: 0.65, blue: 0.0),     // Orange
    CIColor(red: 1.0, green: 1.0, blue: 0.0),      // Yellow
    CIColor(red: 0.65, green: 0.16, blue: 0.16),   // Brown
    CIColor(red: 0.0, green: 1.0, blue: 1.0),      // Cyan
    CIColor(red: 0.0, green: 0.5, blue: 0.5),      // Teal
    CIColor(red: 1.0, green: 0.75, blue: 0.8),     // Pink
    CIColor(red: 1.0, green: 1.0, blue: 1.0),      // White
    CIColor(red: 1.0, green: 0.0, blue: 1.0),      // Magenta
    CIColor(red: 0.5, green: 0.5, blue: 0.5)       // Gray
]


let grayscaleMap: [UInt8: Color] = [
    12: .blue,
    36: .red,
    48: .purple,
    84: .orange,
    96: .brown,
    108: .cyan,
    132: .white,
    144: .teal,
    180: .black,
    216: .green,
    228: .red,
    240: .yellow
]



struct ContentView: View {
    var selection: [Int]
    var classes: [String]
    
    @StateObject private var sharedImageData = SharedImageData()
    @State private var manager: CameraManager?
    @State private var navigateToAnnotationView = false
    
    var body: some View {
        if (navigateToAnnotationView) {
            AnnotationView(sharedImageData: sharedImageData, selection: Array(selection), classes: classes)
        } else {
            VStack {
                if manager?.dataAvailable ?? false{
                    ZStack {
                        HostedCameraViewController(session: manager!.controller.captureSession)
                        HostedSegmentationViewController(sharedImageData: sharedImageData, selection: Array(selection), classes: classes)
                    }
                    
                    NavigationLink(
                        destination: AnnotationView(sharedImageData: sharedImageData, selection: Array(selection), classes: classes),
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
//    var detectionLayer: CALayer! = nil
//    var detectionView: UIImageView! = nil
    
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
        previewLayer.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 325.0)
//        previewLayer.borderWidth = 2.0
//        previewLayer.borderColor = UIColor.blue.cgColor
//        
//        detectionView = UIImageView()
//        detectionView.frame = CGRect(x: 59, y: 366, width: 280, height: 280)
//        detectionView.transform = CGAffineTransform(rotationAngle: -.pi / 2)
//        detectionView.layer.borderWidth = 2.0
//        detectionView.layer.borderColor = UIColor.blue.cgColor
        
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
            //self!.view.layer.addSublayer(self!.detectionLayer)
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
    var selection:[Int] = []
    var classes: [String] = []
    
    static var requests = [VNRequest]()
    
    // define the filter that will convert the grayscale prediction to color image
    //let masker = ColorMasker()
    let masker = CustomCIFilter()
    
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
        segmentationView.frame = CGRect(x: 0.0, y: 325.0, width: 393.0, height: 325.0)
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
        

        let segMaskGray = outPixelBuffer.pixelBuffer
        //let selectedGrayscaleValues: [UInt8] = [12, 36, 48, 84, 96, 108, 132, 144, 180, 216, 228, 240]
//        let selectedGrayscaleValues = convertSelectionToGrayscaleValues(selection: selection, classes: classes, grayscaleMap: grayscaleToClassMap)
//        
        let uniqueGrayscaleValues = extractUniqueGrayscaleValues(from: outPixelBuffer.pixelBuffer)
            print("Unique Grayscale Values: \(uniqueGrayscaleValues)")
        let ciImage = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
        
        //pass through the filter that converts grayscale image to different shades of red
        self.masker.inputImage = ciImage
        self.masker.grayscaleValues = grayValues
        self.masker.colorValues = colors
        //self.masker.count = 12
        self.segmentationView.image = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .up)
        print("b")
        DispatchQueue.main.async {
            self.sharedImageData?.segmentationImage = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .up)
        }
    }
    
    func convertSelectionToGrayscaleValues(selection: [Int], classes: [String], grayscaleMap: [UInt8: String]) -> [UInt8] {
        let selectedClasses = selection.map { classes[$0] }
        let selectedGrayscaleValues = grayscaleMap.compactMap { (key, value) -> UInt8? in
            selectedClasses.contains(value) ? key : nil
        }
        return selectedGrayscaleValues
    }
    
    func preprocessPixelBuffer(_ pixelBuffer: CVPixelBuffer, withSelectedGrayscaleValues selectedValues: [UInt8]) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = CVPixelBufferGetBaseAddress(pixelBuffer)

        let pixelBufferFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        guard pixelBufferFormat == kCVPixelFormatType_OneComponent8 else {
            print("Pixel buffer format is not 8-bit grayscale.")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return
        }

        let selectedValuesSet = Set(selectedValues) // Improve lookup performance
        
        for row in 0..<height {
            let rowBase = buffer!.advanced(by: row * bytesPerRow)
            for column in 0..<width {
                let pixel = rowBase.advanced(by: column)
                let pixelValue = pixel.load(as: UInt8.self)
                if !selectedValuesSet.contains(pixelValue) {
                    pixel.storeBytes(of: 0, as: UInt8.self) // Setting unselected values to 0
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }

    
    
    func extractUniqueGrayscaleValues(from pixelBuffer: CVPixelBuffer) -> Set<UInt8> {
        var uniqueValues = Set<UInt8>()
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bitDepth = 8 // Assuming 8 bits per component in a grayscale image.
        
        let byteBuffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        for row in 0..<height {
            for col in 0..<width {
                let offset = row * bytesPerRow + col * (bitDepth / 8)
                let value = byteBuffer[offset]
                uniqueValues.insert(value)
            }
        }
        
        return uniqueValues
    }

    
    class CustomCIFilter: CIFilter {
        var inputImage: CIImage?
        var grayscaleValues: [Float] = []
        var colorValues: [CIColor] = []


        override var outputImage: CIImage? {
            guard let inputImage = inputImage else { return nil }
            return applyFilter(to: inputImage)
        }

        private func applyFilter(to inputImage: CIImage) -> CIImage? {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue() else {
                return nil
            }
            
            let textureLoader = MTKTextureLoader(device: device)
           
            let ciContext = CIContext(mtlDevice: device)

            guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "colorMatchingKernel"),
                  let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
                return nil
            }

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
            descriptor.usage = [.shaderRead, .shaderWrite]
            
            let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
            
            guard let cgImage = ciContext.createCGImage(inputImage, from: inputImage.extent) else {
                print("Error: inputImage does not have a valid CGImage")
                return nil
            }
                    
            
            guard let inputTexture = try? textureLoader.newTexture(cgImage: cgImage, options: options) else {
                return nil
            }

            guard let outputTexture = device.makeTexture(descriptor: descriptor),
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }

            let grayscaleBuffer = device.makeBuffer(bytes: grayscaleValues, length: grayscaleValues.count * MemoryLayout<Float>.size, options: [])
            let colorBuffer = device.makeBuffer(bytes: colorValues.map { SIMD3<Float>(Float($0.red), Float($0.green), Float($0.blue)) }, length: colorValues.count * MemoryLayout<SIMD3<Float>>.size, options: [])

            commandEncoder.setComputePipelineState(pipeline)
            commandEncoder.setTexture(inputTexture, index: 0)
            commandEncoder.setTexture(outputTexture, index: 1)
            commandEncoder.setBuffer(grayscaleBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(colorBuffer, offset: 0, index: 1)
            commandEncoder.setBytes([UInt32(grayscaleValues.count)], length: MemoryLayout<UInt32>.size, index: 2)
            
            let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                       height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                       depth: 1)
            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            commandEncoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            return CIImage(mtlTexture: outputTexture, options: [.colorSpace: NSNull()])?.oriented(.downMirrored)
        }
    }
}

struct HostedSegmentationViewController: UIViewControllerRepresentable{
    var sharedImageData: SharedImageData
    var selection:[Int]
    var classes: [String]
    
    func makeUIViewController(context: Context) -> SegmentationViewController {
        let viewController = SegmentationViewController(sharedImageData: sharedImageData)
        viewController.selection = selection
        viewController.classes = classes
        return viewController
    }
    
    func updateUIViewController(_ uiView: SegmentationViewController, context: Context) {
    }
}

