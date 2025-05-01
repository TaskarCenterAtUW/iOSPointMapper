//
//  CameraOrientation.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/25.
//

/**
 A class that contains helper methods to manage camera orientation related tasks.
 */
class CameraOrientation {
    
    static func getCGImageOrientationForBackCamera(currentDeviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch currentDeviceOrientation {
            case .portrait:
                return .right                // Camera is rotated 90° CW to be upright
            case .portraitUpsideDown:
                return .left                 // Camera is rotated 90° CCW
            case .landscapeLeft:
                return .up                   // Home button on the right
            case .landscapeRight:
                return .down                 // Home button on the left
            default:
                return .right               // Fallback to portrait
        }
    }
    
    static func getUIImageOrientationForBackCamera(currentDeviceOrientation: UIDeviceOrientation) -> UIImage.Orientation {
        switch currentDeviceOrientation {
            case .portrait:
                return .right
            case .portraitUpsideDown:
                return .left
            case .landscapeLeft:
                return .up
            case .landscapeRight:
                return .down
            default:
                return .right
        }
    }
}
