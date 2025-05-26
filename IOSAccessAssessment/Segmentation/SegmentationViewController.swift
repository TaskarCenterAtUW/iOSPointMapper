//
//  SegmentationViewController.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI


class SegmentationViewController: UIViewController {
    var segmentationView: UIImageView! = nil
    
    var segmentationImage: UIImage?
    
    var selection:[Int] = []
    var classes: [String] = []
    
    init(segmentationImage: UIImage?) {
        self.segmentationView = UIImageView()
        self.segmentationImage = segmentationImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        segmentationView.contentMode = .scaleAspectFit
        segmentationView.translatesAutoresizingMaskIntoConstraints = false
        segmentationView.image = segmentationImage

        view.addSubview(segmentationView)

        NSLayoutConstraint.activate([
            segmentationView.topAnchor.constraint(equalTo: view.topAnchor),
            segmentationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            segmentationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            segmentationView.widthAnchor.constraint(equalTo: segmentationView.heightAnchor, multiplier: aspectRatio)
        ])
    }
    
    private var aspectRatio: CGFloat {
        guard let image = segmentationImage else { return 1.0 }
        return image.size.width / image.size.height
    }
}

struct HostedSegmentationViewController: UIViewControllerRepresentable{
    @Binding var segmentationImage: UIImage?
    
    func makeUIViewController(context: Context) -> SegmentationViewController {
        let viewController = SegmentationViewController(segmentationImage: segmentationImage)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: SegmentationViewController, context: Context) {
        uiViewController.segmentationView.image = segmentationImage
    }
}

