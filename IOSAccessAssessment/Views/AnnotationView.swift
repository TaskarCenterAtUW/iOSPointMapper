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
    @State private var isUpdatingSegmentation = false
    var objectLocation: ObjectLocation
    var selection: [Int]
    var classes: [String]
    let options = ["I agree with this class annotation", "Annotation is missing some instances of the class", "The class annotation is misidentified"]
    
    var body: some View {
        if isShowingCameraView || index >= sharedImageData.classImages.count {
            ContentView(selection: Array(selection), classes: Constants.ClassConstants.classes)
        } else {
            ZStack {
                VStack {
                    HStack {
                        Spacer()
                        HostedAnnotationCameraViewController(sharedImageData: sharedImageData, index: index)
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
                        objectLocation.calcLocation(sharedImageData: sharedImageData, index: index)
                        self.nextSegment()
                        selectedIndex = nil
                    }) {
                        Text("Next")
                    }
                    .padding()
                    .disabled(isUpdatingSegmentation)
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
            .onChange(of: index) { _ in
                // Trigger any additional actions when the index changes
                self.refreshView()
            }
        }
    }
    
    func nextSegment() {
        index += 1
        if index >= (sharedImageData.classImages.count) {
            // Handle completion, save responses, or navigate to the next screen
            ContentView(selection: Array(selection), classes: Constants.ClassConstants.classes)
        }
    }

    func refreshView() {
        // Any additional refresh logic can be placed here
        // Example: fetching new data, triggering animations, etc.
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
    var segmentationImage: CIImage?
    var cameraView: UIImageView? = nil
    var segmentationView: UIImageView? = nil
    var sharedImageData: SharedImageData?
    
    init(sharedImageData: SharedImageData, index: Int) {
        self.cameraImage = sharedImageData.cameraImage
        self.segmentationImage = sharedImageData.classImages[index]
//        self.cameraImage = cameraImage
//        self.segmentationImage = segmentationImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        print("view.bounds.width: \(view.bounds.width)")
//        print("main.bounds.width: \(UIScreen.main.bounds.width)")
        let centerX = (UIScreen.main.bounds.width - 256.0) / 2.0
        cameraView = UIImageView(image: cameraImage)
        cameraView?.frame = CGRect(x: centerX, y: 0.0, width: 256.0, height: 256.0)
        cameraView?.contentMode = .scaleAspectFill
        if let cameraView = cameraView {
            view.addSubview(cameraView)
        }
        
        segmentationView = UIImageView(image: UIImage(ciImage: segmentationImage!, scale: 1.0, orientation: .downMirrored))
        segmentationView?.frame = CGRect(x: centerX, y: 0.0, width: 256.0, height: 256.0)
        segmentationView?.contentMode = .scaleAspectFill
        if let segmentationView = segmentationView {
            view.addSubview(segmentationView)
        }
        cameraView?.bringSubviewToFront(segmentationView!)
    }
}

struct HostedAnnotationCameraViewController: UIViewControllerRepresentable{
//    var cameraImage: UIImage
//    var segmentationImage: UIImage
    let sharedImageData: SharedImageData
    let index: Int
    
    func makeUIViewController(context: Context) -> AnnotationCameraViewController {
        return AnnotationCameraViewController(sharedImageData: sharedImageData, index: index)
    }
    
    func updateUIViewController(_ uiViewController: AnnotationCameraViewController, context: Context) {
        uiViewController.cameraImage = sharedImageData.cameraImage
        uiViewController.segmentationImage = sharedImageData.classImages[index]
//        uiViewController.cameraImage = cameraImage
//        uiViewController.segmentationImage = segmentationImage
        uiViewController.viewDidLoad()
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
