import CoreLocation
import PointNMapShared

struct OSWElementCandidate: Identifiable {
    let element: any OSWElement
    let locationDetails: LocationDetails
    let distance: CLLocationDistance
    let isCaptureMatched: Bool

    var id: String { element.id }
}

enum OSWElementSelectionError: Error, LocalizedError {
    case unknownElementId(String)

    var errorDescription: String? {
        switch self {
        case .unknownElementId(let id):
            return "No relevant OSW element exists with ID \(id)."
        }
    }
}

enum OSWElementSelection: Equatable {
    case newElement
    case existingElement(id: String)

    func resolve(in candidates: [OSWElementCandidate]) throws -> (any OSWElement)? {
        switch self {
        case .newElement:
            return nil
        case .existingElement(let id):
            guard let candidate = candidates.first(where: { $0.id == id }) else {
                throw OSWElementSelectionError.unknownElementId(id)
            }
            return candidate.element
        }
    }
}
