//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
struct AnnotationView: View {
    @ObservedObject var sharedImageData: SharedImageData
    
    var body: some View {
        ZStack {
            HostedAnnotationCameraViewController(cameraImage: sharedImageData.cameraImage!, segmentationImage: sharedImageData.segmentationImage!)
        }
    }
}

class AnnotationCameraViewController: UIViewController {
    var cameraImage: UIImage?
    var segmentationImage: UIImage?
    var cameraView: UIImageView? = nil
    var segmentationView: UIImageView? = nil
    
    init(cameraImage: UIImage, segmentationImage: UIImage) {
        self.cameraImage = cameraImage
        self.segmentationImage = segmentationImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraView = UIImageView(image: cameraImage)
        cameraView!.frame = CGRect(x: 0.0, y: 23.0, width: 393.0, height: 652.0)
        cameraView!.contentMode = .scaleAspectFill
        view.addSubview(cameraView!)
        
        segmentationView = UIImageView(image: segmentationImage)
        segmentationView!.frame = CGRect(x: 0.0, y: 23.0, width: 393.0, height: 652.0)
        segmentationView!.contentMode = .scaleAspectFill
        view.addSubview(segmentationView!)
        cameraView!.bringSubviewToFront(segmentationView!)
    }
}

struct HostedAnnotationCameraViewController: UIViewControllerRepresentable{
    var cameraImage: UIImage
    var segmentationImage: UIImage
    
    func makeUIViewController(context: Context) -> AnnotationCameraViewController {
        return AnnotationCameraViewController(cameraImage: cameraImage, segmentationImage: segmentationImage)
    }
    
    func updateUIViewController(_ uiView: AnnotationCameraViewController, context: Context) {
    }
}

//struct AnnotationView: View {
//    @State private var index = 0
//    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
//    @State private var selectedIndex: Int? = nil
//    @State private var responses = [Int]()
//    let options = ["I agree with this class annotation", "Annotation is missing some instances of the class", "The class annotation is misidentified"]
//    @State private var isShowingCameraView = false
//
//    var capImage: UIImage
//    var capSeg: UIImage
//    var classes: [String]
//    var selection: [Int]
//
//    var body: some View {
//        if (isShowingCameraView == true) {
//            CameraView(selection: Array(selection), classes: classes)
//        } else {
//            ZStack {
//                VStack {
//                    HStack {
//                        Spacer()
//                        Image(uiImage: capImage)
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 200, height: 200)
//                        Spacer()
//                    }
//
//                    HStack {
//                        Spacer()
//                        Text("Selected class: \(classes[selection[index]])")
//                        Spacer()
//                    }
//
//                    ProgressBar(value: calculateProgress(), total: selection.count)
//
//                    HStack {
//                        Spacer()
//                        VStack {
//                            ForEach(0..<options.count) { index in
//                                Button(action: {
//                                    // Toggle selection
//                                    if selectedIndex == index {
//                                        selectedIndex = nil
//                                    } else {
//                                        selectedIndex = index
//                                    }
//                                }) {
//                                    Text(options[index])
//                                        .padding()
//                                        .foregroundColor(selectedIndex == index ? .red : .blue) // Change color based on selection
//                                }
//                            }
//                        }
//                        Spacer()
//                    }
//
//                    Button(action: {
//                        self.nextSegment()
//                        selectedIndex = nil
//                    }) {
//                        Text("Next")
//                    }
//                    .padding()
//                }
//            }
//            .navigationBarTitle("Annotation View", displayMode: .inline)
//            .navigationBarBackButtonHidden(true)
//            .navigationBarItems(leading: Button(action: {
//                // This action depends on how you manage navigation
//                // For demonstration, this simply dismisses the view, but you need a different mechanism to navigate to CameraView
//                self.isShowingCameraView = true;
//            }) {
//                Image(systemName: "chevron.left")
//                    .foregroundColor(.blue)
//                Text("Camera View")
//            })
//
//        }
//
//    }
//
//    func selectOption(option: Int) {
//        responses.append(option)
//    }
//
//    func nextSegment() {
//        index += 1
//        if index >= selection.count {
//            // Handle completion, save responses, or navigate to the next screen
//        }
//    }
//
//    func calculateProgress() -> Float {
//        return Float(index + 1) / Float(selection.count)
//    }
//}
//
//struct ProgressBar: View {
//    var value: Float
//    var total: Int
//
//    var body: some View {
//        ProgressView(value: value, total: Float(total))
//            .progressViewStyle(LinearProgressViewStyle())
//            .padding()
//    }
//}
