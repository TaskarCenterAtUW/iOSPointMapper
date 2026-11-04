import XCTest
@testable import PointNMapShared

final class CapturePresentationStateTests: XCTestCase {
    func testPreparingDisablesCaptureAndShowsActivity() {
        let state = CapturePresentationState.preparing

        XCTAssertFalse(state.isCaptureEnabled)
        XCTAssertTrue(state.showsActivityIndicator)
        XCTAssertFalse(state.isWarning)
    }

    func testReadyEnablesCaptureWithoutActivityOrWarning() {
        let state = CapturePresentationState.ready

        XCTAssertTrue(state.isCaptureEnabled)
        XCTAssertFalse(state.showsActivityIndicator)
        XCTAssertFalse(state.isWarning)
    }

    func testUnavailableDisablesCaptureAndShowsWarning() {
        let state = CapturePresentationState.unavailable(
            explanation: "Waiting for mapping data."
        )

        XCTAssertFalse(state.isCaptureEnabled)
        XCTAssertFalse(state.showsActivityIndicator)
        XCTAssertTrue(state.isWarning)
    }

    func testProcessingDisablesCaptureAndShowsActivity() {
        let state = CapturePresentationState.processing

        XCTAssertFalse(state.isCaptureEnabled)
        XCTAssertTrue(state.showsActivityIndicator)
        XCTAssertFalse(state.isWarning)
    }

    func testCaptureFailureAllowsRetryAndShowsWarning() {
        let state = CapturePresentationState.captureFailed(
            explanation: "No selected features were detected."
        )

        XCTAssertTrue(state.isCaptureEnabled)
        XCTAssertFalse(state.showsActivityIndicator)
        XCTAssertTrue(state.isWarning)
    }
}
