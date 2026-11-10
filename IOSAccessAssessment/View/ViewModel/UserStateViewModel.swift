//
//  UserStateViewModel.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 20.11.2024.
//

import Foundation
import PointNMapShared

@MainActor
class UserStateViewModel: ObservableObject {
    private let userDefaults: UserDefaults

    @Published var selectedEnvironment: APIEnvironment = .staging {
        didSet {
            environmentService.environment = selectedEnvironment
        }
    }
    private let environmentService: EnvironmentService = EnvironmentService.shared
    
    @Published var isAuthenticated: Bool = false
    private let authService: AuthService = AuthService.shared
        
    /**
     Enhanced Analysis enables polygon mesh creation for captured environments.
     
     - WARNING:
        TODO: The initialization of this property should be done by checking if enhanced analysis (polygon mesh creation) is available.
     
     - NOTE:
        This feature may require additional processing power and may not be available on older devices.
     */
    @Published var isEnhancedAnalysisEnabled: Bool {
        didSet {
            userDefaults.set(isEnhancedAnalysisEnabled, forKey: SharedAppConstants.UserDefaultsKeys.isEnhancedAnalysisEnabledKey)
        }
    }
    
    /**
     Select the app mode.
     
        1. Standard Mode: Standard mode allows users to capture new data and perform mapping in real-time, providing an interactive experience.
     
        2. Test Mode: Test mode allows developers to simulate mapping by using existing locally saved input data to perform mapping without needing to capture new data.
     */
    @Published var appMode: AppMode {
        didSet {
            userDefaults.set(appMode.rawValue, forKey: SharedAppConstants.UserDefaultsKeys.appModeKey)
        }
    }

    @Published var lengthUnitChoice: LengthUnitChoice {
        didSet {
            userDefaults.set(
                lengthUnitChoice.rawValue,
                forKey: SharedAppConstants.UserDefaultsKeys.lengthUnitChoiceKey
            )
        }
    }

    @Published var areaUnitChoice: AreaUnitChoice {
        didSet {
            userDefaults.set(
                areaUnitChoice.rawValue,
                forKey: SharedAppConstants.UserDefaultsKeys.areaUnitChoiceKey
            )
        }
    }

    @Published var angleUnitChoice: AngleUnitChoice {
        didSet {
            userDefaults.set(
                angleUnitChoice.rawValue,
                forKey: SharedAppConstants.UserDefaultsKeys.angleUnitChoiceKey
            )
        }
    }

    var measurementUnitPreferences: MeasurementUnitPreferences {
        MeasurementUnitPreferences(
            length: lengthUnitChoice,
            area: areaUnitChoice,
            angle: angleUnitChoice
        )
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.selectedEnvironment = environmentService.environment
        self.isAuthenticated = authService.checkTokenValid()
        self.isEnhancedAnalysisEnabled = userDefaults.bool(
            forKey: SharedAppConstants.UserDefaultsKeys.isEnhancedAnalysisEnabledKey
        )
        if let savedAppModeRawValue = userDefaults.string(
            forKey: SharedAppConstants.UserDefaultsKeys.appModeKey
        ),
           let savedAppMode = AppMode(rawValue: savedAppModeRawValue) {
            self.appMode = savedAppMode
        } else {
            self.appMode = .standard
        }

        self.lengthUnitChoice = LengthUnitChoice(
            rawValue: userDefaults.string(
                forKey: SharedAppConstants.UserDefaultsKeys.lengthUnitChoiceKey
            ) ?? ""
        ) ?? MeasurementUnitPreferences.default.length
        self.areaUnitChoice = AreaUnitChoice(
            rawValue: userDefaults.string(
                forKey: SharedAppConstants.UserDefaultsKeys.areaUnitChoiceKey
            ) ?? ""
        ) ?? MeasurementUnitPreferences.default.area
        self.angleUnitChoice = AngleUnitChoice(
            rawValue: userDefaults.string(
                forKey: SharedAppConstants.UserDefaultsKeys.angleUnitChoiceKey
            ) ?? ""
        ) ?? MeasurementUnitPreferences.default.angle
    }
    
    func updateEnvironment(to newEnvironment: APIEnvironment) {
        selectedEnvironment = newEnvironment
        environmentService.environment = newEnvironment
    }
    
    func login(username: String, password: String) async throws -> AuthResponse {
        let response = try await authService.login(username: username, password: password, environment: selectedEnvironment)
        authService.storeUsername(username: username)
        if let _ = authService.getAccessToken(),
           let _ = authService.getExpirationDate() {
            isAuthenticated = true
            return response
        } else {
            throw NetworkError.unknownError
        }
    }
    
    func callRefreshToken() async throws -> AuthResponse {
        let response = try await authService.callRefreshToken(environment: selectedEnvironment)
        return response
    }
    
    func getAccessToken() -> String? {
        return authService.getAccessToken()
    }
    
    func getUsername() -> String? {
        return authService.getUsername()
    }
    
    func logout() {
        authService.logout()
        
        isAuthenticated = false
    }
}
