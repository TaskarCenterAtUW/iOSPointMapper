//
//  CameraUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/21/25.
//
import AVFoundation

func getCameraDevice() -> AVCaptureDevice? {
    let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInLiDARDepthCamera,
        .builtInTripleCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera
    ]
    
    for deviceType in deviceTypes {
        if let device = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
            return device
        }
    }
    return nil
}

func checkLidarAvailability() -> Bool {
    if let _ = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) {
        return true
    }
    return false
}
