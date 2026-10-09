//
//  AnnotationFeatureDetailView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/28/25.
//

import SwiftUI
import PointNMapShared

enum AnnotationMappedFeatureDetailViewConstants {
    enum Texts {
        static let updateElementTitle: String = "Element to update"
        static let addNewElementTitle: String = "Add a new element"
        
        /// Invalid
        static let invalidTextKey: String = "Invalid"
    }
    
    enum Images {
        /// Alert images
        static let statusAlertImageNameKey: String = "exclamationmark.triangle.fill"
    }
}

/**
    A view that displays detailed information about an accessibility feature annotation.
    Sub-view of the `AnnotationView`.
 */
@ViewBuilder
func AnnotationFeatureDetailView(
    accessibilityFeature: MappedEditableAccessibilityFeature,
    title: String
) -> some View {
    AnnotationFeatureDetailViewBase(
        accessibilityFeature: accessibilityFeature, title: title
    ) { feature in
        let locationFormatter = AnnotationFeatureDetailLocationFormatter()
        Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewLocationKey)) {
            if let featureLocation = accessibilityFeature.getLastLocationCoordinate() {
                VStack {
                    HStack {
                        Spacer()
                        Text(
                            locationFormatter.string(
                                from: NSNumber(value: featureLocation.latitude)
                            ) ?? AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey
                        )
                        .padding(.horizontal)
                        Text(
                            locationFormatter.string(
                                from: NSNumber(value: featureLocation.longitude)
                            ) ?? AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey
                        )
                        .padding(.horizontal)
                        Spacer()
                    }
                    Divider()
                    Picker(
                        AnnotationMappedFeatureDetailViewConstants.Texts.updateElementTitle,
                        selection: Binding<String?>(
                            get: {
                                accessibilityFeature.isExisting ? accessibilityFeature.oswElement?.id : nil
                            },
                            set: { selectedId in
                                guard let selectedId else {
                                    accessibilityFeature.setIsExisting(false)
                                    return
                                }
                                guard let selectedElement = accessibilityFeature.relevantOSWElements.first(where: {
                                    $0.id == selectedId
                                }) else {
                                    return
                                }
                                accessibilityFeature.setOSWElement(oswElement: selectedElement)
                                accessibilityFeature.setIsExisting(true)
                            }
                        )
                    ) {
                        Text(AnnotationMappedFeatureDetailViewConstants.Texts.addNewElementTitle)
                            .tag(nil as String?)
                        ForEach(accessibilityFeature.relevantOSWElements, id: \.id) { oswElement in
                            Text("TDEI Element ID: \(oswElement.id)")
                                .tag(oswElement.id as String?)
                        }
                    }
                    .pickerStyle(.inline)
                }
            } else {
                Text(AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
