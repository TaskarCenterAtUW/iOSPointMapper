import XCTest
@testable import PointNMapShared

final class CaptureHelpContentTests: XCTestCase {
    func testCaptureHelpAssetsHaveStableNames() {
        XCTAssertEqual(
            CaptureHelpAsset.allCases.map(\.name),
            [
                "capture_help_object_good",
                "capture_help_object_adjust",
                "capture_help_sidewalk_direction",
                "capture_help_sidewalk_good",
                "capture_help_sidewalk_adjust"
            ]
        )
    }
}
