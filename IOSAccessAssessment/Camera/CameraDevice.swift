//
//  CameraDevice.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 11/1/24.
//

import Foundation
import AVFoundation

//extension AVCaptureDevice {
//    func set(frameRate: Double) {
//    guard let range = activeFormat.videoSupportedFrameRateRanges.first,
//        range.minFrameRate...range.maxFrameRate ~= frameRate
//        else {
//            print("Requested FPS is not supported by the device's activeFormat !")
//            return
//    }
//
//    do { try lockForConfiguration()
//        activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
//        activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
//        unlockForConfiguration()
//    } catch {
//        print("LockForConfiguration failed with error: \(error.localizedDescription)")
//    }
//  }
//}
extension AVCaptureDevice {

    /// http://stackoverflow.com/questions/21612191/set-a-custom-avframeraterange-for-an-avcapturesession#27566730
    func configureDesiredFrameRate(_ desiredFrameRate: Int) {

        var isFPSSupported = false

        do {

            if let videoSupportedFrameRateRanges = activeFormat.videoSupportedFrameRateRanges as? [AVFrameRateRange] {
                for range in videoSupportedFrameRateRanges {
                    if (range.maxFrameRate >= Double(desiredFrameRate) && range.minFrameRate <= Double(desiredFrameRate)) {
                        isFPSSupported = true
                        break
                    }
                }
            }

            if isFPSSupported {
                try lockForConfiguration()
                activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
                activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
                unlockForConfiguration()
            }

        } catch {
            print("lockForConfiguration error: \(error.localizedDescription)")
        }
    }

}
