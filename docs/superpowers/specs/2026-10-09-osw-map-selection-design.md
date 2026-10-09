# OSW Map Selection Design

## Objective

Add a map-based selector above the existing OSW element button list in the annotation feature detail view. The map renders relevant point and way candidates, highlights a draft selection, and commits the selected existing element or the choice to add a new element. Relation geometry is out of scope.

The existing button list remains available as an accessible fallback and uses the same selection model as the map.

## Current Constraints

- Relevant elements remain limited by the existing 50-meter `fetchUpdateRadiusThresholdInMeters` threshold.
- A capture-ID match remains first and is included regardless of distance.
- Element identity is `OSWElement.id`.
- Duplicate updates to one OSW element remain allowed.
- The upload path continues to read `MappedEditableAccessibilityFeature.isExisting` and `.oswElement`.
- Automated UI tests and simulator UI automation are not part of this implementation. Unit tests, compiler diagnostics, and ordinary builds are required.

## Candidate Model

Replace the UI-facing bare `[any OSWElement]` collection with a map-ready candidate value:

```swift
struct OSWElementCandidate: Identifiable {
    let element: any OSWElement
    let locationDetails: LocationDetails
    let distance: CLLocationDistance?
    let isCaptureMatched: Bool

    var id: String { element.id }
}
```

Candidate geometry is resolved inside `CurrentMappingData`, where way node references and the point dictionary are both available. Neither the button list nor the map view should query global mapping storage.

`MappedEditableAccessibilityFeature` stores `[OSWElementCandidate]`. Its selected `oswElement` remains the authoritative existing element used by upload.

## Geometry Resolution

Supported geometry:

- Point: one coordinate from `OSWPoint`.
- Line string: ordered coordinates resolved from `OSWLineString.pointRefs`.
- Polygon: ordered coordinates resolved from `OSWPolygon.pointRefs`.

A way candidate is rejected if any referenced node is unavailable. A line string requires at least two coordinates. A polygon requires at least three distinct coordinates. Relations and multipolygons are not rendered in this version.

Candidate discovery continues to sort proximity matches nearest-first. If a capture-ID match exists, it is inserted first even when outside the normal threshold and is not duplicated if it is also nearby.

## Selection Model

Use an explicit domain selection:

```swift
enum OSWElementSelection: Equatable {
    case newElement
    case existingElement(id: String)
}
```

The detail view owns the committed selection through `MappedEditableAccessibilityFeature`. The map view owns a draft selection while presented:

- Cancel dismisses without changing the feature.
- Done resolves the candidate ID and updates `oswElement` and `isExisting`.
- Choosing “Add New” commits `isExisting = false`.
- The existing button list commits immediately through the same shared selection operation.

This selection interface remains unchanged if the map renderer later moves from SwiftUI `Map` to `MKMapView`.

## Map Presentation

Add a “Select on Map” button above the existing element selection rows. Present `OSWElementMapSelectionView` as a `fullScreenCover` to provide sufficient space and avoid placing a highly interactive map inside the detail `Form`.

The full-screen map includes:

- Cancel and Done controls.
- A visible summary of the current draft selection.
- An “Add New Element” action.
- The captured feature rendered as distinct, nonselectable context.
- Relevant candidates rendered as selectable map content.

## Rendering

Use SwiftUI `Map` with a `String?` selection binding. Apply each candidate ID with `MapContent.tag(_:)`.

- Point candidates: `Marker` or custom `Annotation`.
- Line-string candidates: `MapPolyline` with a wide translucent stroke to improve hit testing.
- Polygon candidates: `MapPolygon` with a visible boundary and translucent fill.
- Selected content: stronger color, fill, and/or line width.
- Captured feature: visually distinct from all selectable candidates.

The renderer branches on resolved `LocationDetails` geometry rather than performing OSW storage lookups.

If real-device testing later shows inadequate overlay hit testing, only the renderer should be replaced with an `MKMapView` representable; the candidate and selection models remain intact.

## Camera Framing

Build an `MKMapRect` containing every coordinate from the captured feature and every valid candidate. Expand it with padding and enforce a minimum visible span for a single point or tightly grouped coordinates. Initialize the map with `MapCameraPosition.rect(_:)`, then allow normal pan and zoom.

Including all coordinates ensures an out-of-threshold capture-ID match remains visible.

## Accessibility

The existing button list remains the primary non-map selection alternative. Rows retain stable IDs and visible checkmarks. The map screen exposes labeled controls, a textual selection summary, and Cancel/Done actions. Map-only interaction is not required to complete the task.

## Error and Empty States

- No valid candidate geometry: disable or hide “Select on Map” and retain “Add New Element.”
- Candidate geometry becomes invalid during resolution: omit that candidate from map-ready results rather than rendering partial geometry.
- No coordinates for camera framing: show a textual unavailable state and allow cancellation.
- A draft ID cannot be resolved on Done: do not mutate the feature; keep the screen open and present an error.

## Files

Expected changes:

- `IOSAccessAssessment/Shared/Definitions/OSWElementCandidate.swift` — candidate and selection types.
- `IOSAccessAssessment/Shared/Definitions/CurrentMappingData.swift` — candidate discovery and complete geometry resolution.
- `IOSAccessAssessment/AccessibilityFeature/Definitions/MappedEditableAccessibilityFeature.swift` — candidate storage and shared selection operation.
- `IOSAccessAssessment/AccessibilityFeature/AttributeEstimation/Extensions/IsExistingExtension.swift` — populate candidates and preserve capture-ID default behavior.
- `IOSAccessAssessment/View/SubView/OSWElementMapSelectionView.swift` — full-screen SwiftUI map and draft selection.
- `IOSAccessAssessment/View/SubView/AnnotationFeatureDetailView.swift` — map button/presentation and existing list integration.
- `IOSAccessAssessmentTests/IOSAccessAssessmentTests.swift` or focused new unit-test files — candidate resolution, ordering, validation, and selection behavior.

Project-file edits may not be necessary if the project uses synchronized filesystem groups; this must be confirmed during implementation.

## Verification

- Unit tests for point geometry, line geometry, polygon geometry, missing way nodes, insufficient coordinates, proximity ordering, capture-ID inclusion, and selection mutation.
- Live compiler diagnostics for every edited Swift file.
- Ordinary app build.
- No automated UI tests or simulator UI automation. Manual map interaction verification is left to the user.

## Out of Scope

- Relation and multipolygon rendering.
- Preventing multiple captured features from updating the same OSW element.
- Editing candidate geometry on the map.
- Fetching additional map data from within the selector.
- Replacing the existing element button list.
