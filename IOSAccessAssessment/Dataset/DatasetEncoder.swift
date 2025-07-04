//
//  DatasetEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import ARKit
import CryptoKit
import CoreLocation

enum DatasetEncoderStatus {
    case allGood
    case videoEncodingError
    case directoryCreationError
}

class DatasetEncoder {
    private let datasetDirectory: URL
    
    init() {
        self.datasetDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
