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
        /// Is Existing
        static let isExistingTitle: String = "Is this an existing feature?"
        
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
    ) { feature, refreshTrigger in
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
                    HStack {
                        Spacer()
                        Toggle(isOn: Binding(
                            get: { accessibilityFeature.isExisting && accessibilityFeature.oswElement != nil },
                            set: { newValue in
                                accessibilityFeature.setIsExisting(newValue)
                            }
                        )) {
                            Text(AnnotationMappedFeatureDetailViewConstants.Texts.isExistingTitle)
                        }
                        .disabled(accessibilityFeature.oswElement == nil)
                        .foregroundStyle(accessibilityFeature.oswElement == nil ? .secondary : .primary)
                        .strikethrough(accessibilityFeature.oswElement == nil, pattern: .solid)
                        Spacer()
                    }
                    if let oswElement = accessibilityFeature.oswElement {
                        HStack {
                            Spacer()
                            Text("TDEI Element ID: \(oswElement.id)")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    }
                    Divider()
                    if let nearestOSWElements = accessibilityFeature.nearestOSWElements {
                        /// Create a Picker of nearest OSW elements (already sorted by their distances) where user can select the correct one.
                        Picker("Select the correct TDEI element", selection: Binding<String?>(
                            get: { accessibilityFeature.selectedNearestOSWElement?.0.id},
                            set: { newValue in
                                if let newValue = newValue {
                                    accessibilityFeature.selectedNearestOSWElement = nearestOSWElements.first(where: { $0.0.id == newValue })
                                } else {
                                    accessibilityFeature.selectedNearestOSWElement = nil
                                }
                                refreshTrigger.wrappedValue += 1
                            }
                        )) {
                            Text("None selected")
                                .tag(nil as String?)
                            ForEach(nearestOSWElements, id: \.0.id) { (oswElement, distance) in
                                Text("ID: \(oswElement.id), Distance: \(String(format: "%.2f", distance)) m")
                                    .tag(Optional(oswElement.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Divider()
                    /// Create a toggle for isCorrectOSWElementSelected
                    Toggle(isOn: Binding(
                        get: { accessibilityFeature.isCorrectOSWElementSelected },
                        set: { newValue in
                            accessibilityFeature.isCorrectOSWElementSelected = newValue
                        }
                    )) {
                        Text("Is the selected TDEI element correct?")
                    }
                }
            } else {
                Text(AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey)
                    .foregroundStyle(.secondary)
            }
        
        }
    } correctedLocationSection: { feature, refreshTrigger in
        let locationFormatter = AnnotationFeatureDetailLocationFormatter()
        Section(header: Text("Corrected Location")) {
            if let correctedFeatureLocation = accessibilityFeature.getCorrectedLastLocationCoordinate() {
                VStack {
                    HStack {
                        Spacer()
                        Text(
                            locationFormatter.string(
                                from: NSNumber(value: correctedFeatureLocation.latitude)
                            ) ?? AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey
                        )
                        .padding(.horizontal)
                        Text(
                            locationFormatter.string(
                                from: NSNumber(value: correctedFeatureLocation.longitude)
                            ) ?? AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey
                        )
                        .padding(.horizontal)
                        Spacer()
                    }
                    Divider()
                    HStack {
                        Spacer()
                        Toggle(isOn: Binding(
                            get: { accessibilityFeature.correctedIsExisting && accessibilityFeature.correctedOSWElement != nil },
                            set: { newValue in
                                accessibilityFeature.setCorrectedIsExisting(newValue)
                            }
                        )) {
                            Text(AnnotationMappedFeatureDetailViewConstants.Texts.isExistingTitle)
                        }
                        .disabled(accessibilityFeature.correctedOSWElement == nil)
                        .foregroundStyle(accessibilityFeature.correctedOSWElement == nil ? .secondary : .primary)
                        .strikethrough(accessibilityFeature.correctedOSWElement == nil, pattern: .solid)
                        Spacer()
                    }
                    if let correctedOSWElement = accessibilityFeature.correctedOSWElement {
                        HStack {
                            Spacer()
                            Text("TDEI Element ID: \(correctedOSWElement.id)")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    }
                    Divider()
                    if let correctedNearestOSWElements = accessibilityFeature.correctedNearestOSWElements {
                        /// Create a Picker of nearest OSW elements (already sorted by their distances) where user can select the correct one.
                        Picker("Select the correct TDEI element", selection: Binding<String?>(
                            get: { accessibilityFeature.correctedSelectedNearestOSWElement?.0.id},
                            set: { newValue in
                                if let newValue = newValue {
                                    accessibilityFeature.correctedSelectedNearestOSWElement = correctedNearestOSWElements.first(where: { $0.0.id == newValue })
                                } else {
                                    accessibilityFeature.correctedSelectedNearestOSWElement = nil
                                }
                                refreshTrigger.wrappedValue += 1
                            }
                        )) {
                            Text("None selected")
                                .tag(nil as String?)
                            ForEach(correctedNearestOSWElements, id: \.0.id) { (oswElement, distance) in
                                Text("ID: \(oswElement.id), Distance: \(String(format: "%.2f", distance)) m")
                                    .tag(Optional(oswElement.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Divider()
                    /// Create a toggle for isCorrectOSWElementSelected
                    Toggle(isOn: Binding(
                        get: { accessibilityFeature.correctedIsCorrectOSWElementSelected },
                        set: { newValue in
                            accessibilityFeature.correctedIsCorrectOSWElementSelected = newValue
                        }
                    )) {
                        Text("Is the selected TDEI element correct?")
                    }
                }
            } else {
                Text(AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey)
                    .foregroundStyle(.secondary)
            }
        }
    } ambiguitySection: { feature, refreshTrigger in
        let ambiguityCasePolicy = accessibilityFeature.accessibilityFeatureClass.kind.ambiguityCasePolicy
        /// Create a multi-select list of ambiguity cases with checkboxes, where user can select multiple ambiguity cases.
        Section(header: Text("Ambiguity Cases")) {
            ForEach(ambiguityCasePolicy.ambiguityCases, id: \.self) { ambiguityCase in
                HStack {
                    Toggle(isOn: Binding(
                        get: { accessibilityFeature.ambiguityCases.contains(ambiguityCase) },
                        set: { newValue in
                            if newValue {
                                accessibilityFeature.ambiguityCases.append(ambiguityCase)
                            } else {
                                accessibilityFeature.ambiguityCases.removeAll(where: { $0 == ambiguityCase })
                            }
                        }
                    )) {
                        Text(ambiguityCase.rawValue)
                    }
                }
            }
        }
    }
}
