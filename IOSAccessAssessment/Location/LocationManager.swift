//
//  LocationManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import CoreLocation

enum LocationManagerError: Error, LocalizedError {
    case locationUnavailable
    case headingUnavailable
    
    var errorDescription: String? {
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
class LocationManager {
    let locationManager: CLLocationManager
    
    init() {
        self.locationManager = CLLocationManager()
        self.setupLocationManager()
    }
    
    private func setupLocationManager() {
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
    
    private func getLocation() throws -> CLLocation {
        guard let location = locationManager.location,
        location.horizontalAccuracy > 0, location.verticalAccuracy > 0 else {
            throw LocationManagerError.locationUnavailable
        }
        return location
    }
    
    private func getHeading() throws -> CLHeading {
        guard let heading = locationManager.heading,
        heading.headingAccuracy > 0 else {
            throw LocationManagerError.headingUnavailable
        }
        return heading
    }
    
    func getLocationCoordinate() throws -> CLLocationCoordinate2D {
        let location = try getLocation()
        return location.coordinate
    }
}
