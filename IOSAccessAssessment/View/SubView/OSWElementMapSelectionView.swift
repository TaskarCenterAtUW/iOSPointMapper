import SwiftUI
import MapKit
import PointNMapShared

enum OSWElementMapSelectionGeometry {
    static func lineSelectionCoordinate(
        for coordinates: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D? {
        guard let firstCoordinate = coordinates.first else { return nil }

        guard coordinates.count > 1 else { return firstCoordinate }

        let points = coordinates.map(MKMapPoint.init)
        let segmentLengths = zip(points, points.dropFirst()).map { start, end in
            start.distance(to: end)
        }
        let targetDistance = segmentLengths.reduce(0, +) / 2
        var traversedDistance = 0.0

        for index in segmentLengths.indices {
            let segmentLength = segmentLengths[index]
            if traversedDistance + segmentLength >= targetDistance {
                guard segmentLength > 0 else { return points[index].coordinate }
                let progress = (targetDistance - traversedDistance) / segmentLength
                let start = points[index]
                let end = points[index + 1]
                return MKMapPoint(
                    x: start.x + (end.x - start.x) * progress,
                    y: start.y + (end.y - start.y) * progress
                ).coordinate
            }
            traversedDistance += segmentLength
        }

        return points.last?.coordinate
    }

    static func polygonSelectionCoordinate(
        for coordinates: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D? {
        var points = coordinates.map(MKMapPoint.init)
        if let first = points.first, let last = points.last,
           first.x == last.x, first.y == last.y {
            points.removeLast()
        }
        guard points.count >= 3 else {
            return lineSelectionCoordinate(for: coordinates)
        }

        if let centroid = polygonCentroid(points),
           isInside(centroid, polygon: points) {
            return centroid.coordinate
        }

        let boundingCenter = MKMapPoint(
            x: (points.map(\.x).min()! + points.map(\.x).max()!) / 2,
            y: (points.map(\.y).min()! + points.map(\.y).max()!) / 2
        )
        if isInside(boundingCenter, polygon: points) {
            return boundingCenter.coordinate
        }

        let origin = points[0]
        for index in 1..<(points.count - 1) {
            let triangleCenter = MKMapPoint(
                x: (origin.x + points[index].x + points[index + 1].x) / 3,
                y: (origin.y + points[index].y + points[index + 1].y) / 3
            )
            if isInside(triangleCenter, polygon: points) {
                return triangleCenter.coordinate
            }
        }

        return lineSelectionCoordinate(for: coordinates)
    }

    private static func polygonCentroid(_ points: [MKMapPoint]) -> MKMapPoint? {
        var signedArea = 0.0
        var centroidX = 0.0
        var centroidY = 0.0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let crossProduct = current.x * next.y - next.x * current.y
            signedArea += crossProduct
            centroidX += (current.x + next.x) * crossProduct
            centroidY += (current.y + next.y) * crossProduct
        }
        guard abs(signedArea) > .ulpOfOne else { return nil }
        return MKMapPoint(
            x: centroidX / (3 * signedArea),
            y: centroidY / (3 * signedArea)
        )
    }

    private static func isInside(_ point: MKMapPoint, polygon: [MKMapPoint]) -> Bool {
        LocationHelpers.MKDistanceHelpers.checkPointInsidePolygon(
            srcPoint: point,
            polygonPoints: polygon
        )
    }
}

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

    private let hasMapContent: Bool

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

        let mapRect = OSWElementMapViewport.makeVisibleMapRect(
            candidates: candidates,
            capturedFeatureLocation: capturedFeatureLocation
        )
        hasMapContent = mapRect != nil
        _cameraPosition = State(initialValue: mapRect.map(MapCameraPosition.rect) ?? .automatic)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapContent
                selectionControls
            }
            .navigationTitle("Select Element")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        confirmSelection()
                    }
                }
            }
            .alert(
                "Selection Unavailable",
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
    }

    @ViewBuilder
    private var mapContent: some View {
        if hasMapContent {
            Map(position: $cameraPosition, selection: $draftElementId) {
                capturedFeatureMapContent
                ForEach(candidates) { candidate in
                    candidateMapContent(candidate)
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
    }

    private var selectionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectionSummary)
                .font(.headline)
                .accessibilityLabel("Current selection")
                .accessibilityValue(selectionSummary)
            Button("Add a New Element") {
                draftElementId = nil
            }
            .accessibilityHint("Creates a new network element instead of updating an existing one.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
    }

    private var selectionSummary: String {
        draftElementId.map { "TDEI Element ID: \($0)" } ?? "Add a new element"
    }

    private func confirmSelection() {
        let selection = draftElementId.map(OSWElementSelection.existingElement(id:))
            ?? .newElement
        do {
            try onConfirm(selection)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MapContentBuilder
    private var capturedFeatureMapContent: some MapContent {
        ForEach(
            Array(capturedFeatureLocation.locations.enumerated()),
            id: \.offset
        ) { _, location in
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
                if let coordinate = OSWElementMapSelectionGeometry.polygonSelectionCoordinate(
                    for: location.coordinates
                ) {
                    capturedFeatureAnnotation(
                        coordinate: coordinate,
                        geometryName: "polygon"
                    )
                }
            } else {
                MapPolyline(coordinates: location.coordinates)
                    .stroke(.purple, style: StrokeStyle(lineWidth: 6, dash: [8, 5]))
                if let coordinate = OSWElementMapSelectionGeometry.lineSelectionCoordinate(
                    for: location.coordinates
                ) {
                    capturedFeatureAnnotation(
                        coordinate: coordinate,
                        geometryName: "line"
                    )
                }
            }
        }
    }

    private func capturedFeatureAnnotation(
        coordinate: CLLocationCoordinate2D,
        geometryName: String
    ) -> Annotation<Text, some View> {
        Annotation("Captured feature", coordinate: coordinate) {
            Image(systemName: "scope")
                .padding(8)
                .background(.white, in: Circle())
                .foregroundStyle(.purple)
                .accessibilityLabel("Captured feature \(geometryName)")
                .accessibilityHint("This is the feature currently being annotated.")
        }
    }

    @MapContentBuilder
    private func candidateMapContent(_ candidate: OSWElementCandidate) -> some MapContent {
        if let location = candidate.locationDetails.locations.last {
            if !location.isWay, let coordinate = location.coordinates.first {
                Marker(candidate.id, coordinate: coordinate)
                    .tint(candidate.id == draftElementId ? .green : .blue)
                    .tag(candidate.id)
            } else if location.isClosed {
                MapPolygon(coordinates: location.coordinates)
                    .foregroundStyle(
                        candidate.id == draftElementId
                            ? Color.green.opacity(0.45)
                            : Color.blue.opacity(0.25)
                    )
                    .stroke(
                        candidate.id == draftElementId ? .green : .blue,
                        lineWidth: candidate.id == draftElementId ? 6 : 3
                    )
                if let coordinate = OSWElementMapSelectionGeometry.polygonSelectionCoordinate(
                    for: location.coordinates
                ) {
                    candidateSelectionAnnotation(
                        candidate: candidate,
                        coordinate: coordinate,
                        systemImage: "pentagon.fill",
                        geometryName: "polygon"
                    )
                }
            } else {
                MapPolyline(coordinates: location.coordinates)
                    .stroke(
                        candidate.id == draftElementId ? .green : .blue,
                        lineWidth: candidate.id == draftElementId ? 10 : 7
                    )
                if let coordinate = OSWElementMapSelectionGeometry.lineSelectionCoordinate(
                    for: location.coordinates
                ) {
                    candidateSelectionAnnotation(
                        candidate: candidate,
                        coordinate: coordinate,
                        systemImage: "point.3.connected.trianglepath.dotted",
                        geometryName: "line"
                    )
                }
            }
        }
    }

    private func candidateSelectionAnnotation(
        candidate: OSWElementCandidate,
        coordinate: CLLocationCoordinate2D,
        systemImage: String,
        geometryName: String
    ) -> Annotation<Text, some View> {
        Annotation("Select \(geometryName) \(candidate.id)", coordinate: coordinate) {
            Button {
                draftElementId = candidate.id
            } label: {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        candidate.id == draftElementId ? Color.green : Color.blue,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select TDEI \(geometryName) element \(candidate.id)")
            .accessibilityValue(candidate.id == draftElementId ? "Selected" : "Not selected")
        }
    }
}
