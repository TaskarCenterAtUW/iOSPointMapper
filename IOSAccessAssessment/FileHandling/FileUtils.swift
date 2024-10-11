//
//  FileUtils.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 10/10/24.
//

import SwiftUI

func generateFileNameWithTimestamp(prefix: String = "file", fileExtension: String = "txt") -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
    let timestamp = dateFormatter.string(from: Date())
    
    return "\(prefix)_\(timestamp).\(fileExtension)"
}

func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}
