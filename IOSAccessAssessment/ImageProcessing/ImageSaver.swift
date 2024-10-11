//
//  ImageSaver.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 10/10/24.
//

import SwiftUI

class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    func writeDepthMapToPhotoAlbum(cvPixelBufferDepth: CVPixelBuffer) {
        // Print for good measure
        printDepthPixel(from: cvPixelBufferDepth, atX: 10, atY: 10)
        printDepthPixel(from: cvPixelBufferDepth, atX: 128, atY: 128)
        printDepthPixel(from: cvPixelBufferDepth, atX: 256, atY: 256)
        
        // CVPixelBuffer to UIImage
        let ciImageDepth            = CIImage(cvPixelBuffer: cvPixelBufferDepth)
        let contextDepth:CIContext  = CIContext.init(options: nil)
        let cgImageDepth:CGImage    = contextDepth.createCGImage(ciImageDepth, from: ciImageDepth.extent)!
        let uiImageDepth:UIImage    = UIImage(cgImage: cgImageDepth, scale: 1, orientation: UIImage.Orientation.up)

        // Save UIImage to Photos Album
        UIImageWriteToSavedPhotosAlbum(uiImageDepth, self, #selector(saveCompleted), nil)
    }
    
    func writeCIImageToPhotoAlbum(ciImage: CIImage) {
        let contextDepth:CIContext  = CIContext.init(options: nil)
        let cgImageDepth:CGImage    = contextDepth.createCGImage(ciImage, from: ciImage.extent)!
        let uiImageDepth:UIImage    = UIImage(cgImage: cgImageDepth, scale: 1, orientation: UIImage.Orientation.up)

        // Save UIImage to Photos Album
        UIImageWriteToSavedPhotosAlbum(uiImageDepth, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("Save finished!")
    }
}

