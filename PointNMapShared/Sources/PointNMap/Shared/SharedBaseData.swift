//
//  SharedBaseData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import SwiftUI
import Combine
import simd

@MainActor
final class SharedBaseData: ObservableObject {
    @Published var isUploadReady: Bool = false
    var isLidarAvailable: Bool = ARCameraUtils.checkDepthSupport()
    
    var currentCaptureDataRecord: CaptureData?
    /// A queue to hold recent capture image data.
    var captureDataQueue: SafeDeque<CaptureImageData>
    var captureDataCapacity: Int
    
    init(captureDataCapacity: Int = 5) {
        self.captureDataCapacity = captureDataCapacity
        self.captureDataQueue = SafeDeque<CaptureImageData>(capacity: captureDataCapacity)
    }
    
    func refreshQueue() async {
        await self.captureDataQueue.removeAll()
    }
    
    func refreshData() {
        self.isUploadReady = false
        self.currentCaptureDataRecord = nil
    }
    
    func saveCaptureData(_ data: CaptureData) {
        self.currentCaptureDataRecord = data
    }
    
    func appendCaptureDataToQueue(_ data: (any CaptureImageDataProtocol)) async {
        let captureImageData = CaptureImageData(data)
        await self.captureDataQueue.appendBack(captureImageData)
    }
}
