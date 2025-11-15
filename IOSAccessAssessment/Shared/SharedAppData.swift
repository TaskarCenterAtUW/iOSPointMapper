//
//  SharedAppData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import SwiftUI
import DequeModule
import simd

@MainActor
final class SharedAppData: ObservableObject {
    @Published var isUploadReady: Bool = false
    var isLidarAvailable: Bool = ARCameraUtils.checkDepthSupport()
    var currentDatasetEncoder: DatasetEncoder?
    
    var currentCaptureDataRecord: (any CaptureImageDataProtocol)?
    var captureDataQueue: SafeDeque<(any CaptureImageDataProtocol)>
    var captureDataCapacity: Int
    
    init(captureDataCapacity: Int = 5) {
        self.captureDataCapacity = captureDataCapacity
        self.captureDataQueue = SafeDeque<(any CaptureImageDataProtocol)>(capacity: captureDataCapacity)
    }
    
    func refreshData() {
        self.isUploadReady = false
        self.currentDatasetEncoder = nil
        self.currentCaptureDataRecord = nil
    }
    
    func saveCaptureData(_ data: (any CaptureImageDataProtocol)) async {
        self.currentCaptureDataRecord = data
//        await self.captureDataQueue.appendBack(data)
    }
}
