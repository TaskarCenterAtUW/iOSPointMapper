//
//  CameraOrientation.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/25.
//
import Foundation
import UIKit

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
                return .up                   // (Home button on the right) Camera is not rotated.
            case .landscapeRight:
                return .down                 // (Home button on the left) Camera is rotated 180°.
            default:
                return .right               // Fallback to portrait
        }
    }
    
    static func getCGImageReverseOrientationForBackCamera(currentDeviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch currentDeviceOrientation {
        case .portrait:
            return .left                 // Camera is rotated 90° CCW to revert to original orientation
        case .portraitUpsideDown:
            return .right                // Camera is rotated 90° CW to revert to original orientation
        case .landscapeLeft:
            return .up                 // Home button on the right, camera is rotated 180°
        case .landscapeRight:
            return .down                   // Home button on the left, camera is rotated 180°
        default:
            return .left                // Fallback to portrait
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
    
    // Since people tend to hold devices in portrait mode by default when using the camera,
    // we can assume that the camera is in portrait mode when the device orientation is unknown.
    static func isLandscapeOrientation(currentDeviceOrientation: UIDeviceOrientation) -> Bool {
        return currentDeviceOrientation == .landscapeLeft || currentDeviceOrientation == .landscapeRight
    }
}

extension CGImagePropertyOrientation {
    var inverted: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .right
        case .right: return .left
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .rightMirrored
        case .rightMirrored: return .leftMirrored
        @unknown default: return .up
        }
    }
}
