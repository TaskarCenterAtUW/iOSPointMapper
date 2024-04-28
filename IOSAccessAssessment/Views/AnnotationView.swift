//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
struct AnnotationView: View {
    @ObservedObject var sharedImageData: SharedImageData
    @State private var index = 0
    @State private var selectedIndex: Int? = nil
    @State private var isShowingCameraView = false
    var selection: [Int]
    var classes: [String]
    let options = ["I agree with this class annotation", "Annotation is missing some instances of the class", "The class annotation is misidentified"]
    
    var body: some View {
        if (isShowingCameraView == true || index >= selection.count) {
            ContentView(selection: Array(selection), classes: classes)
        } else {
            ZStack {
                VStack {
                    HStack {
                        Spacer()
                        if (index > 0) {
                            HostedAnnotationCameraViewController(cameraImage: sharedImageData.cameraImage!, segmentationImage: sharedImageData.objectSegmentation!)
                        } else {
                            HostedAnnotationCameraViewController(cameraImage: sharedImageData.cameraImage!, segmentationImage: sharedImageData.segmentationImage!)
                        }
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("Selected class: \(classes[selection[index]])")
                        Spacer()
                    }
                    
                    ProgressBar(value: calculateProgress())
                    
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
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: Button(action: {
                // This action depends on how you manage navigation
                // For demonstration, this simply dismisses the view, but you need a different mechanism to navigate to CameraView
                self.isShowingCameraView = true;
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
                Text("Camera View")
            })
            .padding()
        }
    }
    
    func nextSegment() {
        index += 1
        if index >= (selection.count) {
            // Handle completion, save responses, or navigate to the next screen
            ContentView(selection: Array(selection), classes: classes)
        }
    }

    func calculateProgress() -> Float {
        return Float(index) / Float(selection.count)
    }
}

struct ProgressBar: View {
    var value: Float


    var body: some View {
        ProgressView(value: value)
            .progressViewStyle(LinearProgressViewStyle())
            .padding()
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
        let centerX = (view.bounds.width - 250.0) / 2.0;
        cameraView!.frame = CGRect(x: centerX, y: 50.0, width: 200.0, height: 200.0)
        cameraView!.contentMode = .scaleAspectFill
        view.addSubview(cameraView!)
        
        segmentationView = UIImageView(image: segmentationImage)
        segmentationView!.frame = CGRect(x: centerX, y: 50.0, width: 200.0, height: 200.0)
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
