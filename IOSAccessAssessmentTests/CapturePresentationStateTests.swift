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

    func testInitialStateDoesNotProduceAccessibilityAnnouncement() {
        XCTAssertNil(CapturePresentationState.preparing.accessibilityAnnouncement(after: nil))
    }

    func testStateTransitionsAnnounceOnlyNewHeadings() {
        let transitions: [(CapturePresentationState, CapturePresentationState, String)] = [
            (.preparing, .ready, "Capture status: Ready to capture"),
            (.ready, .unavailable(explanation: "Waiting for mapping data."), "Capture status: Capture unavailable"),
            (.unavailable(explanation: "Waiting for mapping data."), .processing, "Capture status: Processing capture…"),
            (.processing, .captureFailed(explanation: "No selected features were detected."), "Capture status: Capture unsuccessful")
        ]

        for (previousState, newState, expectedHeading) in transitions {
            XCTAssertEqual(
                newState.accessibilityAnnouncement(after: previousState),
                expectedHeading
            )
        }
    }

    func testTransitionBackToPreparingAnnouncesHeading() {
        XCTAssertEqual(
            CapturePresentationState.preparing.accessibilityAnnouncement(after: .ready),
            "Capture status: Preparing capture…"
        )
    }

    func testUnchangedHeadingDoesNotRepeatAccessibilityAnnouncement() {
        let previousState = CapturePresentationState.unavailable(
            explanation: "Waiting for mapping data."
        )
        let newState = CapturePresentationState.unavailable(
            explanation: "Location is unavailable."
        )

        XCTAssertNil(newState.accessibilityAnnouncement(after: previousState))
    }
}
