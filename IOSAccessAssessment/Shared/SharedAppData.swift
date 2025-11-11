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
    
    var currentCaptureDataRecord: CaptureData?
    var captureDataQueue: SafeDeque<CaptureData>
    var captureDataCapacity: Int
    
    init(captureDataCapacity: Int = 5) {
        self.captureDataCapacity = captureDataCapacity
        self.captureDataQueue = SafeDeque<CaptureData>(capacity: captureDataCapacity)
    }
    
    func refreshData() {
        self.isUploadReady = false
        self.currentDatasetEncoder = nil
        self.currentCaptureDataRecord = nil
    }
    
    func saveCaptureData(_ data: CaptureData) async {
        self.currentCaptureDataRecord = data
        await self.captureDataQueue.appendBack(data)
    }
}
