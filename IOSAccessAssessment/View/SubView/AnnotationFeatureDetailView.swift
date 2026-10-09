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
        static let selectOnMapTitle: String = "Select on Map"
        
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
    @State private var isMapSelectionPresented = false

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

                if !accessibilityFeature.relevantOSWElements.isEmpty,
                   accessibilityFeature.locationDetails != nil {
                    Button {
                        isMapSelectionPresented = true
                    } label: {
                        Label(
                            AnnotationMappedFeatureDetailViewConstants.Texts.selectOnMapTitle,
                            systemImage: "map"
                        )
                    }
                    .accessibilityLabel("Select an existing element on the map")
                }

                selectionButton(
                    title: AnnotationMappedFeatureDetailViewConstants.Texts.addNewElementTitle,
                    elementId: nil
                )
                .id("new-element")

                ForEach(accessibilityFeature.relevantOSWElements) { candidate in
                    selectionButton(title: "TDEI Element ID: \(candidate.id)", elementId: candidate.id)
                        .id("osw-element-\(candidate.id)")
                }
            } else {
                Text(AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey)
                    .foregroundStyle(.secondary)
            }
        }
        .fullScreenCover(isPresented: $isMapSelectionPresented) {
            if let capturedFeatureLocation = accessibilityFeature.locationDetails {
                OSWElementMapSelectionView(
                    candidates: accessibilityFeature.relevantOSWElements,
                    capturedFeatureLocation: capturedFeatureLocation,
                    initialSelection: currentSelection
                ) { selection in
                    try accessibilityFeature.applyOSWElementSelection(selection)
                    refreshTrigger += 1
                }
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

    private var currentSelection: OSWElementSelection {
        if accessibilityFeature.isExisting, let id = accessibilityFeature.oswElement?.id {
            return .existingElement(id: id)
        }
        return .newElement
    }

    private func selectElement(id: String?) {
        let selection = id.map(OSWElementSelection.existingElement(id:)) ?? .newElement
        guard (try? accessibilityFeature.applyOSWElementSelection(selection)) != nil else { return }
        refreshTrigger += 1
    }
}
