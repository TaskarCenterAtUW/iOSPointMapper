//
//  LocationManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import CoreLocation
import UIKit
import MapKit
import Combine

public enum LocationManagerError: Error, LocalizedError {
    case locationUnavailable
    case headingUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Location data is unavailable."
        case .headingUnavailable:
            return "Heading data is unavailable."
        }
    }
}

/**
 A wrapper around CLLocationManager to manage location and heading updates in a more controlled and safe manner.
 */
@MainActor
public class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager = CLLocationManager()
    
    @Published public var currentLocation: CLLocation?
    @Published public var currentHeading: CLHeading?
    
    public override init() {
        super.init()
    }
    
    public func startLocationUpdates() {
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // TODO: Sync heading with the device orientation
        locationManager.headingOrientation = .portrait
        locationManager.headingFilter = kCLHeadingFilterNone
        
        locationManager.pausesLocationUpdatesAutomatically = false // Prevent auto-pausing
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    /**
    Updates the heading orientation of the location manager based on the current device orientation. This ensures that heading data is accurate and consistent with the user's perspective.
     */
    public func updateOrientation(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait:
            locationManager.headingOrientation = .portrait
        case .portraitUpsideDown:
            locationManager.headingOrientation = .portraitUpsideDown
        /// Flipped because the heading is relative to the device's top, which is opposite in landscape orientations
        case .landscapeLeft:
            locationManager.headingOrientation = .landscapeRight
        case .landscapeRight:
            locationManager.headingOrientation = .landscapeLeft
        default:
            locationManager.headingOrientation = .portrait
        }
    }
    
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        guard let horizontalAccuracy = latestLocation.horizontalAccuracy as CLLocationAccuracy?,
                let verticalAccuracy = latestLocation.verticalAccuracy as CLLocationAccuracy?,
              horizontalAccuracy > 0, verticalAccuracy > 0 else {
            return
        }
        Task { @MainActor in
            self.currentLocation = latestLocation
        }
    }
    
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard let headingAccuracy = newHeading.headingAccuracy as CLLocationDirection?,
              headingAccuracy > 0 else {
            return
        }
        Task { @MainActor in
            self.currentHeading = newHeading
        }
    }
    
    public func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
}
