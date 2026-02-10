//
//  MTLTextureUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/8/26.
//

import Metal

extension MTLTexture {
    /**
        Returns a string representation of the pixel format type of the metal texture.
     */
    func pixelFormatName() -> String {
        let p = self.pixelFormat
        switch p {
        case .r8Unorm: return "r8Unorm"
        case .r16Float: return "r16Float"
        case .r32Float: return "r32Float"
        case .rgba8Unorm: return "rgba8Unorm"
        case .rgba16Float: return "rgba16Float"
        default: return "Other (\(p))"
        }
    }
}
