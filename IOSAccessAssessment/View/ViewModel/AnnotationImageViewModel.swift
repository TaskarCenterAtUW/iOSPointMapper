//
//  AnnotationImageViewModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/12/25.
//

import SwiftUI

class AnnotationImageViewModel: ObservableObject {
    @Published var cameraUIImage: UIImage? = nil
    
    func update(cameraImage: CIImage, orientation: UIInterfaceOrientation) {
        objectWillChange.send()
    }
}
