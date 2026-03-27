//
//  CGImageUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//

import UIKit

extension CGImage {
    // TODO: Need to check if this is applicable to all image types
    func getByteSize() -> Int {
        var bytesPerRow: Int = 4 * self.width
        if (bytesPerRow % 16 != 0) {
            bytesPerRow = ((bytesPerRow / 16) + 1) * 16;
        }
        return self.height * bytesPerRow;
    }
}
