//
//  AnnotationOption.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/25/25.
//

enum AnnotationOptionClass: String, CaseIterable {
    case agree = "I agree with this class annotation"
    case missingInstances = "Annotation is missing some instances"
//    case misidentified = "The class annotation is misidentified"
    case discard = "I wish to discard this class annotation"
}

enum AnnotationOptionObject: String, CaseIterable {
    case agree = "I agree with this object annotation"
    case discard = "I wish to discard this object annotation"
}

protocol AnnotationOptionProtocol: RawRepresentable, CaseIterable, Hashable where RawValue == String {}

extension AnnotationOptionClass: AnnotationOptionProtocol {}
extension AnnotationOptionObject: AnnotationOptionProtocol {}

enum AnnotationOption: Hashable {
    case classOption(AnnotationOptionClass)
    case individualOption(AnnotationOptionObject)
    
    var rawValue: String {
        switch self {
        case .classOption(let option): return option.rawValue
        case .individualOption(let option): return option.rawValue
        }
    }
}
