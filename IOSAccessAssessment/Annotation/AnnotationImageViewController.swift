//
//  AnnotationCameraViewController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/10/25.
//

import SwiftUI

@MainActor
protocol AnnotationImageProcessingOutputConsumer: AnyObject {
    
}

protocol AnnotationImageProcessingDelegate: AnyObject {
    @MainActor
    var outputConsumer: AnnotationImageProcessingOutputConsumer? { get set }
    @MainActor
    func setOrientation(_ orientation: UIInterfaceOrientation)
}

class AnnotationImageViewController: UIViewController, AnnotationImageProcessingOutputConsumer {
    var annotationImageManager: AnnotationImageManager
    
    private let subView = UIView()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(white: 0, alpha: 0.0)
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let overlayView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(white: 0, alpha: 0.0)
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    init(annotationImageManager: AnnotationImageManager) {
        self.annotationImageManager = annotationImageManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(subView)
        subView.clipsToBounds = true
        subView.translatesAutoresizingMaskIntoConstraints = false
        let subViewBoundsConstraints: [NSLayoutConstraint] = [
            subView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            subView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),
            subView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            subView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ]
        NSLayoutConstraint.activate(subViewBoundsConstraints)
        
        subView.addSubview(imageView)
        constraintChildViewToParent(childView: imageView, parentView: subView)
        subView.addSubview(overlayView)
        constraintChildViewToParent(childView: overlayView, parentView: subView)
    }
    
    private func constraintChildViewToParent(childView: UIView, parentView: UIView) {
        NSLayoutConstraint.deactivate(childView.constraints)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: parentView.topAnchor),
            childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
        ])
    }
    
    func getOrientation() -> UIInterfaceOrientation {
        // TODO: While we are requested to replace usage with effectiveGeometry.interfaceOrientation,
        //  it seems to cause issues with getting the correct orientation.
        //  Need to investigate further.
        if let io = view.window?.windowScene?.interfaceOrientation {
            return io
        }
        // Fallback for early lifecycle / no window
        if view.bounds.height >= view.bounds.width {
            return .portrait
        }
        return .landscapeLeft
    }
}

struct HostedAnnotationImageViewController: UIViewControllerRepresentable{
    @ObservedObject var annotationImageManager: AnnotationImageManager
    
    func makeUIViewController(context: Context) -> AnnotationImageViewController {
        let vc = AnnotationImageViewController(annotationImageManager: annotationImageManager)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: AnnotationImageViewController, context: Context) {
    }
    
    static func dismantleUIViewController(_ uiViewController: AnnotationImageViewController, coordinator: ()) {
    }
}
