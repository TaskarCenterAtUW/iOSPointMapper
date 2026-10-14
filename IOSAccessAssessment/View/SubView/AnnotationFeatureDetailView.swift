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
        static let invalidTextKey = "Invalid"
        static let elementToUpdateTitle = "Element to Update"
        static let selectOnMapTitle = "Select Network Element on Map"
        static let addNewElementTitle = "Add a New Element"
        static let selectionUnavailableTitle = "Selection Unavailable"
    }

    enum Images {
        static let statusAlertImageNameKey = "exclamationmark.triangle.fill"
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
    AnnotationFeatureDetailContainer(
        accessibilityFeature: accessibilityFeature,
        title: title
    )
}

private struct AnnotationFeatureDetailContainer: View {
    let accessibilityFeature: MappedEditableAccessibilityFeature
    let title: String

    @State private var selectedElementId: String?
    @State private var mapPresentation: OSWElementMapPresentation?
    @State private var errorMessage: String?

    init(
        accessibilityFeature: MappedEditableAccessibilityFeature,
        title: String
    ) {
        self.accessibilityFeature = accessibilityFeature
        self.title = title
        _selectedElementId = State(
            initialValue: accessibilityFeature.isExisting
                ? accessibilityFeature.oswElement?.id
                : nil
        )
    }

    var body: some View {
        AnnotationFeatureDetailViewBase(
            accessibilityFeature: accessibilityFeature,
            title: title
        ) { feature in
            AnnotationFeatureLocationSection(
                accessibilityFeature: feature,
                selectedElementId: $selectedElementId,
                onSelect: applySelection,
                onPresentMap: presentMap
            )
        }
        .fullScreenCover(item: $mapPresentation) { presentation in
            OSWElementMapSelectionView(
                candidates: presentation.candidates,
                capturedFeatureLocation: presentation.capturedFeatureLocation,
                initialSelection: presentation.initialSelection,
                onConfirm: applySelection
            )
        }
        .alert(
            AnnotationMappedFeatureDetailViewConstants.Texts.selectionUnavailableTitle,
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please select another element.")
        }
    }

    private func presentMap() {
        guard let locationDetails = accessibilityFeature.locationDetails else {
            errorMessage = "No coordinates are available for this feature."
            return
        }
        mapPresentation = OSWElementMapPresentation(
            candidates: accessibilityFeature.relevantOSWElements,
            capturedFeatureLocation: locationDetails,
            initialSelection: currentSelection
        )
    }

    private var currentSelection: OSWElementSelection {
        selectedElementId.map(OSWElementSelection.existingElement(id:))
            ?? .newElement
    }

    private func applySelection(_ selection: OSWElementSelection) throws {
        do {
            try accessibilityFeature.applyOSWElementSelection(selection)
            switch selection {
            case .newElement:
                selectedElementId = nil
            case .existingElement(let id):
                selectedElementId = id
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

private struct OSWElementMapPresentation: Identifiable {
    let id = UUID()
    let candidates: [OSWElementCandidate]
    let capturedFeatureLocation: LocationDetails
    let initialSelection: OSWElementSelection
}

private struct AnnotationFeatureLocationSection: View {
    let accessibilityFeature: MappedEditableAccessibilityFeature
    @Binding var selectedElementId: String?
    let onSelect: (OSWElementSelection) throws -> Void
    let onPresentMap: () -> Void

    private let locationFormatter = AnnotationFeatureDetailLocationFormatter()

    var body: some View {
        Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewLocationKey)) {
            if let featureLocation = accessibilityFeature.getLastLocationCoordinate() {
                AnnotationFeatureCoordinateRow(
                    latitude: formatted(featureLocation.latitude),
                    longitude: formatted(featureLocation.longitude)
                )

                if canPresentMap {
                    Label(
                        AnnotationMappedFeatureDetailViewConstants.Texts.selectOnMapTitle,
                        systemImage: "map"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded(onPresentMap))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(
                        "Shows nearby compatible network elements and the captured feature."
                    )
                    .accessibilityAction { onPresentMap() }
                }

                Text(AnnotationMappedFeatureDetailViewConstants.Texts.elementToUpdateTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                AnnotationFeatureSelectionRow(
                    title: AnnotationMappedFeatureDetailViewConstants.Texts.addNewElementTitle,
                    isSelected: selectedElementId == nil
                ) {
                    select(elementId: nil)
                }

                ForEach(accessibilityFeature.relevantOSWElements) { candidate in
                    AnnotationFeatureSelectionRow(
                        title: "TDEI Element ID: \(candidate.id)",
                        isSelected: selectedElementId == candidate.id
                    ) {
                        select(elementId: candidate.id)
                    }
                }
            } else {
                Text(AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canPresentMap: Bool {
        accessibilityFeature.locationDetails != nil
            && !accessibilityFeature.relevantOSWElements.isEmpty
    }

    private func select(elementId: String?) {
        let selection = elementId.map(OSWElementSelection.existingElement(id:))
            ?? .newElement
        try? onSelect(selection)
    }

    private func formatted(_ value: CLLocationDegrees) -> String {
        locationFormatter.string(from: NSNumber(value: value))
            ?? AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey
    }
}

private struct AnnotationFeatureSelectionRow: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .highPriorityGesture(TapGesture().onEnded(onSelect))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAction { onSelect() }
    }
}

private struct AnnotationFeatureCoordinateRow: View {
    let latitude: String
    let longitude: String

    var body: some View {
        HStack {
            Spacer()
            Text(latitude)
                .padding(.horizontal)
            Text(longitude)
                .padding(.horizontal)
            Spacer()
        }
    }
}
