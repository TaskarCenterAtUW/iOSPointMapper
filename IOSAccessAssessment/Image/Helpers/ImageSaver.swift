//
//  ImageSaver.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/15/25.
//

import SwiftUI

/**
 A class to save image objects to the photo album.
    Currently only supports UIImage and CIImage objects.
 */
class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage, normalize: Bool = true) {
        let imageToSave: UIImage
        if normalize {
            imageToSave = normalizedImage(image)
        } else {
            imageToSave = image
        }
        
        UIImageWriteToSavedPhotosAlbum(imageToSave, self, #selector(saveCompleted), nil)
    }
    
    func writeToPhotoAlbumUnbackedCIImage(image: CIImage) {
        let context = CIContext()
        let cgImage = context.createCGImage(image, from: image.extent)
        guard let cgImageUnwrapped = cgImage else {
            print("Failed to create CGImage from CIImage")
            return
        }
        let uiImage = UIImage(cgImage: cgImageUnwrapped, scale: 1.0, orientation: .right)
        UIImageWriteToSavedPhotosAlbum(uiImage, self, #selector(saveCompleted), nil)
    }

    func normalizedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("Save finished!")
    }
}
