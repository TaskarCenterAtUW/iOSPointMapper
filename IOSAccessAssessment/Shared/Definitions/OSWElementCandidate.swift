import CoreLocation
import PointNMapShared

struct OSWElementCandidate: Identifiable {
    let element: any OSWElement
    let locationDetails: LocationDetails
    /// Distance from the captured feature in MKMapPoint units.
    let mapPointDistance: Double
    let isCaptureMatched: Bool

    var id: String { element.id }
}

enum OSWElementSelectionError: Error, LocalizedError {
    case unknownElementId(String)
    case geometryMismatch(expected: MappingGeometry, actual: MappingGeometry)

    var errorDescription: String? {
        switch self {
        case .unknownElementId(let id):
            return "No relevant OSW element exists with ID \(id)."
        case .geometryMismatch(let expected, let actual):
            return "The selected OSW element uses \(actual) geometry instead of \(expected) geometry."
        }
    }
}

enum OSWElementSelection: Equatable {
    case newElement
    case existingElement(id: String)
}
