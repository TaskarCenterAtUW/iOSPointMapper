# OSW Map Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full-screen map selector that renders nearby point, line-string, and polygon OSW elements and commits the user’s chosen existing element or “add new” choice.

**Architecture:** Resolve OSW storage objects into self-contained map-ready candidates inside `CurrentMappingData`, where way node coordinates are available. Present those candidates through a SwiftUI `Map` whose draft ID selection is independent from the committed feature selection; the existing button list and the map both commit through the same domain selection operation.

**Tech Stack:** Swift, SwiftUI, MapKit, CoreLocation, XCTest, Xcode build and diagnostic tools.

**Spec:** `docs/superpowers/specs/2026-10-09-osw-map-selection-design.md`

## Global Constraints

- Keep the existing 50-meter `fetchUpdateRadiusThresholdInMeters` candidate threshold.
- Include and prioritize a capture-ID match regardless of distance.
- Use `OSWElement.id` as stable identity.
- Support point, line-string, and polygon elements; do not add relation or multipolygon support.
- Preserve the existing upload contract through `MappedEditableAccessibilityFeature.isExisting` and `.oswElement`.
- Keep the existing button list as an accessible fallback.
- Do not run automated UI tests or simulator UI automation.
- Do not commit, push, or release without explicit authorization.

## Review Focus

- A capture-ID match with incomplete way geometry is omitted safely and the nearest valid candidate becomes the default; covered in Task 1.
- A polygon whose first coordinate is repeated at the end still has three distinct vertices and remains valid; covered in Task 1.
- Duplicate element IDs never produce duplicate candidates or ambiguous map tags; covered in Task 1.
- Empty and single-point coordinate sets produce a usable map state rather than an invalid zero-sized camera rectangle; covered in Task 3.
- Candidate sets near the ±180° longitude boundary do not frame nearly the entire world; covered in Task 3.

---

### Task 1: Map-Ready Candidate Resolution

**Files:**
- Create: `IOSAccessAssessment/Shared/Definitions/OSWElementCandidate.swift`
- Modify: `IOSAccessAssessment/Shared/Definitions/CurrentMappingData.swift:174-356`
- Modify: `IOSAccessAssessmentTests/IOSAccessAssessmentTests.swift`

**Interfaces:**
- Consumes: `OSWElement`, `LocationDetails`, `CurrentMappingData.points`, and existing feature-class geometry.
- Produces: `OSWElementCandidate`, `OSWElementSelection`, `OSWElementSelection.resolve(in:)`, and `CurrentMappingData.getRelevantFeatures(...) -> [OSWElementCandidate]`.

- [ ] **Step 1: Write failing candidate-resolution tests**

Add XCTest cases named:

- `testRelevantPointCandidatesAreFilteredAndSortedNearestFirst`
- `testRelevantLineStringCandidateResolvesNodeCoordinatesInReferenceOrder`
- `testRelevantPolygonCandidateAcceptsRepeatedClosingCoordinate`
- `testRelevantWayCandidateIsOmittedWhenAnyNodeIsMissing`
- `testCaptureMatchedCandidateIsFirstOutsideThreshold`
- `testInvalidCaptureMatchedCandidateFallsBackToNearestValidCandidate`
- `testRelevantCandidatesDoNotDuplicateElementIds`
- `testExistingElementSelectionResolvesCandidateAndUnknownIdThrows`

Assert candidate IDs, resolved coordinates, `distance`, `isCaptureMatched`, invalid-geometry omission, and selection resolution using hand-built `CurrentMappingData` fixtures.

- [ ] **Step 2: Run the new unit tests and verify RED**

Run the named tests with Xcode `RunSomeTests` under `IOSAccessAssessmentTests`.

Expected: build/test failure because `OSWElementCandidate`, `OSWElementSelection`, and the new candidate return type do not exist.

- [ ] **Step 3: Add the candidate and selection types**

Create:

```swift
struct OSWElementCandidate: Identifiable {
    let element: any OSWElement
    let locationDetails: LocationDetails
    let distance: CLLocationDistance
    let isCaptureMatched: Bool
    var id: String { element.id }
}

enum OSWElementSelection: Equatable {
    case newElement
    case existingElement(id: String)

    func resolve(in candidates: [OSWElementCandidate]) throws -> (any OSWElement)?
}
```

Define a focused error for an unknown existing-element ID. `newElement` resolves to `nil`.

- [ ] **Step 4: Change candidate discovery to resolve complete geometry**

Change:

```swift
func getRelevantFeatures(
    to locationDetails: LocationDetails,
    featureClass: AccessibilityFeatureClass,
    captureId: UUID?,
    distanceThreshold: CLLocationDistance = 50.0
) -> [OSWElementCandidate]
```

Resolve point, line-string, and polygon `LocationDetails` inside `CurrentMappingData`. Reject partial ways, line strings with fewer than two coordinates, and polygons with fewer than three distinct coordinates. Sort valid proximity candidates by distance, de-duplicate by element ID, and place a valid capture match first regardless of threshold.

- [ ] **Step 5: Run Task 1 tests and verify GREEN**

Run the eight Task 1 tests with Xcode `RunSomeTests`.

Expected: eight passed, zero failed or skipped.

- [ ] **Step 6: Refresh diagnostics for Task 1 files**

Run `XcodeRefreshCodeIssuesInFile` for the candidate, mapping-data, and test files.

Expected: no diagnostics.

### Task 2: Feature Storage and Shared Selection Commit

**Files:**
- Modify: `IOSAccessAssessment/AccessibilityFeature/Definitions/MappedEditableAccessibilityFeature.swift:11-81`
- Modify: `IOSAccessAssessment/AccessibilityFeature/AttributeEstimation/Extensions/IsExistingExtension.swift:11-36`
- Modify: `IOSAccessAssessment/View/SubView/AnnotationFeatureDetailView.swift:42-127`
- Modify: `IOSAccessAssessmentTests/IOSAccessAssessmentTests.swift`

**Interfaces:**
- Consumes: `[OSWElementCandidate]` and `OSWElementSelection` from Task 1.
- Produces: `relevantOSWElements: [OSWElementCandidate]` and `applyOSWElementSelection(_:) throws` on `MappedEditableAccessibilityFeature`.

- [ ] **Step 1: Write failing feature-selection tests**

Add tests:

- `testApplyingExistingCandidateMarksFeatureExistingAndStoresElement`
- `testApplyingNewElementSelectionMarksFeatureNotExisting`
- `testApplyingUnknownCandidateDoesNotMutateFeature`

Use the project’s real feature types and assert `isExisting` and `oswElement?.id`.

- [ ] **Step 2: Run Task 2 tests and verify RED**

Run the three tests with Xcode `RunSomeTests`.

Expected: failure because candidate storage and `applyOSWElementSelection(_:)` are unavailable.

- [ ] **Step 3: Implement candidate storage and atomic selection**

Change candidate storage to `[OSWElementCandidate]` and add:

```swift
func applyOSWElementSelection(_ selection: OSWElementSelection) throws
```

Resolve before mutating so an unknown ID leaves both `isExisting` and `oswElement` unchanged. Update the estimation pipeline to store candidate results and default to the first candidate while retaining `isExistingFirst` policy.

- [ ] **Step 4: Route the existing button list through the shared operation**

Update list rows to use `candidate.id` and call `applyOSWElementSelection(_:)`. Keep stable row IDs, checkmarks derived from the feature model, and the existing refresh-only state.

- [ ] **Step 5: Run Task 2 and prior tests**

Run all `IOSAccessAssessmentTests` with Xcode `RunSomeTests` or `RunAllTests` limited to the unit-test target.

Expected: all unit tests passed; zero failed or skipped.

### Task 3: Map Rendering, Selection, and Camera Framing

**Files:**
- Create: `IOSAccessAssessment/View/SubView/OSWElementMapSelectionView.swift`
- Modify: `IOSAccessAssessmentTests/IOSAccessAssessmentTests.swift`

**Interfaces:**
- Consumes: `[OSWElementCandidate]`, `LocationDetails`, and `OSWElementSelection`.
- Produces: `OSWElementMapSelectionView`, `OSWElementMapViewport.makeVisibleMapRect(...)`, and `onConfirm: (OSWElementSelection) -> Void`.

- [ ] **Step 1: Write failing camera-framing tests**

Add tests:

- `testVisibleMapRectIncludesCapturedAndCandidateCoordinates`
- `testVisibleMapRectUsesMinimumSpanForSingleCoordinate`
- `testVisibleMapRectReturnsNilForNoCoordinates`
- `testVisibleMapRectUsesWrappedLongitudeSpanAcrossAntimeridian`

Assert containment, nonzero width/height, nil empty state, and a narrow wrapped span for coordinates immediately east and west of the antimeridian.

- [ ] **Step 2: Run camera tests and verify RED**

Expected: failure because `OSWElementMapViewport` does not exist.

- [ ] **Step 3: Implement the viewport helper**

Add:

```swift
enum OSWElementMapViewport {
    static func makeVisibleMapRect(
        candidates: [OSWElementCandidate],
        capturedFeatureLocation: LocationDetails
    ) -> MKMapRect?
}
```

Include all coordinates, add visual padding, enforce a minimum point span, and account for the wrapped world-map x-axis when choosing the shortest longitude extent.

- [ ] **Step 4: Implement the full-screen map selector**

Add a dedicated `View` with:

```swift
init(
    candidates: [OSWElementCandidate],
    capturedFeatureLocation: LocationDetails,
    initialSelection: OSWElementSelection,
    onConfirm: @escaping (OSWElementSelection) -> Void
)
```

Use `MapCameraPosition.rect(_:)`, a `String?` map selection binding, and tagged `Marker`, `MapPolyline`, or `MapPolygon` content. Render the captured feature as nonselectable context. Keep draft selection local until Done, provide Add New and Cancel actions, and display a textual selection summary.

- [ ] **Step 5: Verify compiler diagnostics before integration**

Run `XcodeRefreshCodeIssuesInFile` for the new map view and tests.

Expected: no diagnostics.

- [ ] **Step 6: Run camera and all prior unit tests**

Expected: all unit tests passed; zero failed or skipped.

### Task 4: Detail-View Presentation and Unified Commit

**Files:**
- Modify: `IOSAccessAssessment/View/SubView/AnnotationFeatureDetailView.swift`

**Interfaces:**
- Consumes: `OSWElementMapSelectionView` and `MappedEditableAccessibilityFeature.applyOSWElementSelection(_:)`.
- Produces: a “Select on Map” button above the existing list and a full-screen map presentation.

- [ ] **Step 1: Add map-presentation state and button**

Add private presentation state to `AnnotationFeatureLocationSection`. Show “Select on Map” above “Add a New Element” only when at least one valid candidate exists and captured feature location is available.

- [ ] **Step 2: Present the map and derive its initial selection**

Use `fullScreenCover` to provide candidates, captured location, and the feature’s current selection. On confirmation, call the shared selection operation, update the refresh token, and dismiss. On cancellation, do not mutate the feature.

- [ ] **Step 3: Add accessible labels and selection summary text**

Ensure the map-opening button, Add New action, candidate selection, Cancel, and Done have human-readable labels. Preserve the existing button list and checkmarks as the non-map alternative.

- [ ] **Step 4: Refresh detail-view diagnostics**

Run `XcodeRefreshCodeIssuesInFile` for `AnnotationFeatureDetailView.swift`.

Expected: no diagnostics.

### Task 5: Final Regression Verification

**Files:**
- Verify all files changed in Tasks 1–4.

**Interfaces:**
- Consumes: the completed candidate, selection, map, and detail-view integrations.
- Produces: verified build and unit-test evidence.

- [ ] **Step 1: Run the complete unit-test target**

Use Xcode test tools to execute `IOSAccessAssessmentTests` only.

Expected: every unit test executed and passed; zero failed or skipped. Report counts explicitly.

- [ ] **Step 2: Refresh diagnostics for every edited Swift file**

Expected: no compiler diagnostics.

- [ ] **Step 3: Build the ordinary app target**

Use Xcode `BuildProject` without build-for-testing.

Expected: successful build with zero errors.

- [ ] **Step 4: Review the final diff against the spec**

Confirm point/line/polygon support, capture-ID behavior, 50-meter threshold, accessible list fallback, draft map selection, and no relation support or unrelated changes.

- [ ] **Step 5: Hand off manual checks**

Report that automated UI tests and simulator interaction were not run. Provide manual checks for point selection, line selection, polygon selection, Add New, Cancel, Done, selected highlighting, capture-ID outlier framing, and fallback list synchronization.
