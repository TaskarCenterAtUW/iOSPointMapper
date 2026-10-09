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
        AnnotationFeatureLocationSection(accessibilityFeature: feature)
    }
}

private struct AnnotationFeatureLocationSection: View {
    let accessibilityFeature: MappedEditableAccessibilityFeature

    @State private var refreshTrigger = 0

    private let locationFormatter = AnnotationFeatureDetailLocationFormatter()

    var body: some View {
        Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewLocationKey)) {
            if let featureLocation = accessibilityFeature.getLastLocationCoordinate() {
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

                selectionButton(
                    title: AnnotationMappedFeatureDetailViewConstants.Texts.addNewElementTitle,
                    elementId: nil
                )
                .id("new-element")

                ForEach(accessibilityFeature.relevantOSWElements, id: \.id) { oswElement in
                    selectionButton(title: "TDEI Element ID: \(oswElement.id)", elementId: oswElement.id)
                        .id("osw-element-\(oswElement.id)")
                }
            } else {
                Text(AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func selectionButton(title: String, elementId: String?) -> some View {
        Button {
            selectElement(id: elementId)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected(elementId: elementId) {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isSelected(elementId: String?) -> Bool {
        _ = refreshTrigger
        if accessibilityFeature.isExisting {
            return accessibilityFeature.oswElement?.id == elementId
        }
        return elementId == nil
    }

    private func selectElement(id: String?) {
        guard let id else {
            accessibilityFeature.setIsExisting(false)
            refreshTrigger += 1
            return
        }
        guard let selectedElement = accessibilityFeature.relevantOSWElements.first(where: {
            $0.id == id
        }) else {
            return
        }
        accessibilityFeature.setOSWElement(oswElement: selectedElement)
        accessibilityFeature.setIsExisting(true)
        refreshTrigger += 1
    }
}
