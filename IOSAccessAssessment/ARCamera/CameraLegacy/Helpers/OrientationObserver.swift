//
//  OrientationObserver.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

import Combine
import UIKit

final class OrientationObserver: ObservableObject {
    @Published var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                let orientation = UIDevice.current.orientation
                if orientation.isValidInterfaceOrientation {
                    self?.deviceOrientation = orientation
                }
            }
            .store(in: &cancellables)
    }
}
