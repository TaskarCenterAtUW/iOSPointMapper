import SwiftUI
import MapKit
import PointNMapShared

enum OSWElementMapViewport {
    static func makeVisibleMapRect(
        candidates: [OSWElementCandidate],
        capturedFeatureLocation: LocationDetails
    ) -> MKMapRect? {
        let coordinates = capturedFeatureLocation.locations.flatMap(\.coordinates)
            + candidates.flatMap { $0.locationDetails.locations.flatMap(\.coordinates) }
        guard !coordinates.isEmpty else { return nil }

        let worldWidth = MKMapSize.world.width
        let mapPoints = coordinates.map(MKMapPoint.init)
        let sortedX = mapPoints.map(\.x).sorted()
        var largestGap = -Double.infinity
        var startIndex = 0
        for index in sortedX.indices {
            let nextIndex = (index + 1) % sortedX.count
            let nextX = nextIndex == 0 ? sortedX[nextIndex] + worldWidth : sortedX[nextIndex]
            let gap = nextX - sortedX[index]
            if gap > largestGap {
                largestGap = gap
                startIndex = nextIndex
            }
        }

        let startX = sortedX[startIndex]
        let unwrappedPoints = mapPoints.map { point in
            MKMapPoint(x: point.x < startX ? point.x + worldWidth : point.x, y: point.y)
        }
        let minX = unwrappedPoints.map(\.x).min() ?? startX
        let maxX = unwrappedPoints.map(\.x).max() ?? startX
        let minY = unwrappedPoints.map(\.y).min() ?? 0
        let maxY = unwrappedPoints.map(\.y).max() ?? 0
        let minimumSpan = 200.0
        let width = max(maxX - minX, minimumSpan)
        let height = max(maxY - minY, minimumSpan)
        let rect = MKMapRect(
            x: (minX + maxX - width) / 2,
            y: (minY + maxY - height) / 2,
            width: width,
            height: height
        )
        return rect.insetBy(dx: -width * 0.2, dy: -height * 0.2)
    }
}

struct OSWElementMapSelectionView: View {
    let candidates: [OSWElementCandidate]
    let capturedFeatureLocation: LocationDetails
    let onConfirm: (OSWElementSelection) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftElementId: String?
    @State private var cameraPosition: MapCameraPosition
    @State private var errorMessage: String?

    init(
        candidates: [OSWElementCandidate],
        capturedFeatureLocation: LocationDetails,
        initialSelection: OSWElementSelection,
        onConfirm: @escaping (OSWElementSelection) throws -> Void
    ) {
        self.candidates = candidates
        self.capturedFeatureLocation = capturedFeatureLocation
        self.onConfirm = onConfirm
        let selectedId: String?
        switch initialSelection {
        case .newElement:
            selectedId = nil
        case .existingElement(let id):
            selectedId = id
        }
        _draftElementId = State(initialValue: selectedId)
        if let rect = OSWElementMapViewport.makeVisibleMapRect(
            candidates: candidates,
            capturedFeatureLocation: capturedFeatureLocation
        ) {
            _cameraPosition = State(initialValue: .rect(rect))
        } else {
            _cameraPosition = State(initialValue: .automatic)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if OSWElementMapViewport.makeVisibleMapRect(
                    candidates: candidates,
                    capturedFeatureLocation: capturedFeatureLocation
                ) != nil {
                    Map(position: $cameraPosition, selection: $draftElementId) {
                        capturedFeatureContent
                        ForEach(candidates) { candidate in
                            candidateContent(candidate)
                        }
                    }
                    .mapStyle(.standard)
                } else {
                    ContentUnavailableView(
                        "Map Unavailable",
                        systemImage: "map",
                        description: Text("No coordinates are available for this feature.")
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(selectionSummary)
                        .font(.headline)
                        .accessibilityLabel("Current selection: \(selectionSummary)")
                    Button("Add a New Element") {
                        draftElementId = nil
                    }
                    .accessibilityLabel("Add a new element instead of updating an existing element")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("Select Element")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let selection = draftElementId.map { OSWElementSelection.existingElement(id: $0) } ?? .newElement
                        do {
                            try onConfirm(selection)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .alert("Selection Unavailable", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please select another element.")
            }
        }
    }

    private var selectionSummary: String {
        draftElementId.map { "TDEI Element ID: \($0)" } ?? "Add a new element"
    }

    @MapContentBuilder
    private var capturedFeatureContent: some MapContent {
        ForEach(Array(capturedFeatureLocation.locations.enumerated()), id: \.offset) { index, location in
            if !location.isWay, let coordinate = location.coordinates.first {
                Annotation("Captured feature", coordinate: coordinate) {
                    Image(systemName: "scope")
                        .padding(8)
                        .background(.white, in: Circle())
                        .foregroundStyle(.purple)
                        .accessibilityLabel("Captured feature")
                }
            } else if location.isClosed {
                MapPolygon(coordinates: location.coordinates)
                    .foregroundStyle(Color.purple.opacity(0.2))
                    .stroke(.purple, lineWidth: 4)
            } else {
                MapPolyline(coordinates: location.coordinates)
                    .stroke(.purple, style: StrokeStyle(lineWidth: 6, dash: [8, 5]))
            }
        }
    }

    @MapContentBuilder
    private func candidateContent(_ candidate: OSWElementCandidate) -> some MapContent {
        if let location = candidate.locationDetails.locations.last {
            if !location.isWay, let coordinate = location.coordinates.first {
                Marker(candidate.id, coordinate: coordinate)
                    .tint(candidate.id == draftElementId ? .green : .blue)
                    .tag(candidate.id)
            } else if location.isClosed {
                MapPolygon(coordinates: location.coordinates)
                    .foregroundStyle(candidate.id == draftElementId ? Color.green.opacity(0.45) : Color.blue.opacity(0.25))
                    .stroke(candidate.id == draftElementId ? .green : .blue, lineWidth: candidate.id == draftElementId ? 6 : 3)
                    .tag(candidate.id)
            } else {
                MapPolyline(coordinates: location.coordinates)
                    .stroke(candidate.id == draftElementId ? .green : .blue, lineWidth: candidate.id == draftElementId ? 10 : 7)
                    .tag(candidate.id)
            }
        }
    }
}
