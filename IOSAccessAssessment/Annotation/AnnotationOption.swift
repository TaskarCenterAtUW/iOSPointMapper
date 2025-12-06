//
//  AnnotationOption.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/25/25.
//

protocol AnnotationOptionProtocol: RawRepresentable, CaseIterable, Hashable where RawValue == String {}

enum AnnotationOptionFeature: String, CaseIterable, Hashable, AnnotationOptionProtocol {
    case agree = "I agree with this feature annotation"
    case discard = "I wish to discard this feature annotation"
    
    static let `default` = AnnotationOptionFeature.agree
}

enum AnnotationOptionFeatureClass: String, CaseIterable, Hashable, AnnotationOptionProtocol {
    case agree = "I agree with this class annotation"
    case missingInstances = "Annotation is missing some instances"
//    case misidentified = "The class annotation is misidentified"
    case discard = "I wish to discard this class annotation"
    
    static let `default` = AnnotationOptionFeatureClass.agree
}

enum AnnotationOption: Hashable {
    case individualOption(AnnotationOptionFeature)
    case classOption(AnnotationOptionFeatureClass)
    
    var rawValue: String {
        switch self {
        case .individualOption(let option): return option.rawValue
        case .classOption(let option): return option.rawValue
        }
    }
}
