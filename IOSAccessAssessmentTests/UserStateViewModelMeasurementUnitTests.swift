import XCTest
@testable import IOSAccessAssessment
@testable import PointNMapShared

@MainActor
final class UserStateViewModelMeasurementUnitTests: XCTestCase {
    func testLoadsPersistedMeasurementUnitChoicesIndependently() {
        withIsolatedDefaults { defaults in
            defaults.set("feet", forKey: SharedAppConstants.UserDefaultsKeys.lengthUnitChoiceKey)
            defaults.set(
                "squareInches",
                forKey: SharedAppConstants.UserDefaultsKeys.areaUnitChoiceKey
            )
            defaults.set("radians", forKey: SharedAppConstants.UserDefaultsKeys.angleUnitChoiceKey)

            let viewModel = UserStateViewModel(userDefaults: defaults)

            XCTAssertEqual(viewModel.lengthUnitChoice, .feet)
            XCTAssertEqual(viewModel.areaUnitChoice, .squareInches)
            XCTAssertEqual(viewModel.angleUnitChoice, .radians)
        }
    }

    func testInvalidMeasurementUnitChoiceFallsBackWithoutResettingOtherDimensions() {
        withIsolatedDefaults { defaults in
            defaults.set(
                "unsupported-length-unit",
                forKey: SharedAppConstants.UserDefaultsKeys.lengthUnitChoiceKey
            )
            defaults.set(
                "squareFeet",
                forKey: SharedAppConstants.UserDefaultsKeys.areaUnitChoiceKey
            )
            defaults.set("radians", forKey: SharedAppConstants.UserDefaultsKeys.angleUnitChoiceKey)

            let viewModel = UserStateViewModel(userDefaults: defaults)

            XCTAssertEqual(viewModel.lengthUnitChoice, .meters)
            XCTAssertEqual(viewModel.areaUnitChoice, .squareFeet)
            XCTAssertEqual(viewModel.angleUnitChoice, .radians)
        }
    }

    func testMissingMeasurementUnitChoiceFallsBackWithoutResettingOtherDimensions() {
        withIsolatedDefaults { defaults in
            defaults.set("inches", forKey: SharedAppConstants.UserDefaultsKeys.lengthUnitChoiceKey)
            defaults.set(
                "squareInches",
                forKey: SharedAppConstants.UserDefaultsKeys.areaUnitChoiceKey
            )

            let viewModel = UserStateViewModel(userDefaults: defaults)

            XCTAssertEqual(viewModel.lengthUnitChoice, .inches)
            XCTAssertEqual(viewModel.areaUnitChoice, .squareInches)
            XCTAssertEqual(viewModel.angleUnitChoice, .degrees)
        }
    }

    func testChangingMeasurementUnitChoicesPersistsStableIdentifiers() {
        withIsolatedDefaults { defaults in
            let viewModel = UserStateViewModel(userDefaults: defaults)

            viewModel.lengthUnitChoice = .feet
            viewModel.areaUnitChoice = .squareFeet
            viewModel.angleUnitChoice = .radians

            XCTAssertEqual(
                defaults.string(
                    forKey: SharedAppConstants.UserDefaultsKeys.lengthUnitChoiceKey
                ),
                "feet"
            )
            XCTAssertEqual(
                defaults.string(
                    forKey: SharedAppConstants.UserDefaultsKeys.areaUnitChoiceKey
                ),
                "squareFeet"
            )
            XCTAssertEqual(
                defaults.string(
                    forKey: SharedAppConstants.UserDefaultsKeys.angleUnitChoiceKey
                ),
                "radians"
            )
        }
    }

    func testMeasurementUnitPreferencesReflectCurrentChoices() {
        withIsolatedDefaults { defaults in
            let viewModel = UserStateViewModel(userDefaults: defaults)
            viewModel.lengthUnitChoice = .inches
            viewModel.areaUnitChoice = .squareFeet
            viewModel.angleUnitChoice = .radians

            XCTAssertEqual(
                viewModel.measurementUnitPreferences,
                MeasurementUnitPreferences(
                    length: .inches,
                    area: .squareFeet,
                    angle: .radians
                )
            )
        }
    }

    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "UserStateViewModelMeasurementUnitTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        body(defaults)
    }
}
