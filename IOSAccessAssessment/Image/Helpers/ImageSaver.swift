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
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
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


    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("Save finished!")
    }
}
