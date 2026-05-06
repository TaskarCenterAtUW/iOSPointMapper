//
//  AnnotationOption.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/25/25.
//

public protocol AnnotationOptionProtocol: RawRepresentable, CaseIterable, Hashable where RawValue == String {}

public enum AnnotationOptionFeature: String, CaseIterable, Hashable, AnnotationOptionProtocol {
    case agree = "I agree with this feature annotation"
    case discard = "I wish to discard this feature annotation"
    
    public static let `default` = AnnotationOptionFeature.agree
}

public enum AnnotationOptionFeatureClass: String, CaseIterable, Hashable, AnnotationOptionProtocol {
    case agree = "I agree with this class annotation"
    case missingInstances = "Annotation is missing some instances"
//    case misidentified = "The class annotation is misidentified"
    case discard = "I wish to discard this class annotation"
    
    public static let `default` = AnnotationOptionFeatureClass.agree
}

public enum AnnotationOption: Hashable {
    case individualOption(AnnotationOptionFeature)
    case classOption(AnnotationOptionFeatureClass)
    
    public var rawValue: String {
        switch self {
        case .individualOption(let option): return option.rawValue
        case .classOption(let option): return option.rawValue
        }
    }
}
