# Testing

The initial unit-test foundation uses the existing `IOSAccessAssessmentTests`
XCTest target in the shared `IOSAccessAssessment` scheme and its
`IOSAccessAssessment` test plan.

## Requirements

- Xcode with an iOS simulator whose OS is at least the project's iOS 18.5
  deployment target
- Swift package dependencies resolved by Xcode (`swift-collections` 1.5.1)
- No login, network connection, sensor input, or test credentials are required

The setup was build-verified with the iPhone 17 simulator running iOS 27.0.

## Run the focused test in Xcode

1. Open `IOSAccessAssessment.xcodeproj` in Xcode.
2. Select the shared `IOSAccessAssessment` scheme.
3. Confirm the `IOSAccessAssessment` test plan is active.
4. Select an available iOS simulator (verified build destination: iPhone 17,
   iOS 27.0).
5. Open the Test navigator and run
   `IOSAccessAssessmentTests/testCustomOSWFieldPreservesMetadata()`.

## Run the unit-test target from Terminal

From the repository root, run:

```sh
xcodebuild test \
  -project IOSAccessAssessment.xcodeproj \
  -scheme IOSAccessAssessment \
  -testPlan IOSAccessAssessment \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:IOSAccessAssessmentTests
```

To run only the foundation test, replace the final selector with:

```sh
-only-testing:IOSAccessAssessmentTests/IOSAccessAssessmentTests/testCustomOSWFieldPreservesMetadata
```

The test bundle and host app build successfully for testing. During the initial
verification session, the simulator test launch remained in Xcode's `started`
state without returning an XCTest result, so successful execution was not
confirmed in that session.
