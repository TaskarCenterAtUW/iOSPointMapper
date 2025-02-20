//
//  ImageSaver.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/15/25.
//

import SwiftUI

/**
 A class to save image objects to the photo album.
    Currently only supports UIImage objects.
 */
class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("Save finished!")
    }
}
