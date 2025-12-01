//
//  LocationManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import CoreLocation

enum LocationError: Error, LocalizedError {
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

class LocationManager {
    let locationManager: CLLocationManager
    var longitude: CLLocationDegrees?
    var latitude: CLLocationDegrees?
    var altitude: CLLocationDistance?
    var headingDegrees: CLLocationDirection?
    
    init() {
        self.locationManager = CLLocationManager()
        self.longitude = nil
        self.latitude = nil
        self.headingDegrees = nil
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
    
    private func setLocation() throws {
        // TODO: Ensure that the horizontal and vertical accuracy are acceptable
        // Else, do not update the location
        guard let location = locationManager.location,
        location.horizontalAccuracy > 0, location.verticalAccuracy > 0 else {
            throw LocationError.locationUnavailable
        }
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
    }
    
    private func setHeading() throws {
        guard let heading = locationManager.heading,
        heading.headingAccuracy > 0 else {
            throw LocationError.headingUnavailable
        }
        self.headingDegrees = heading.trueHeading
    }
    
    func setLocationAndHeading(maxRetries: Int = 3) throws {
        var retries = 0
        while retries < maxRetries {
            do {
                try self.setLocation()
                /// Currently, we are not using heading information
//                try self.setHeading()
                return
            } catch {
                if retries == maxRetries - 1 {
                    throw error
                }
                retries += 1
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }
    
    func getLocation() throws -> CLLocationCoordinate2D {
        guard let latitude = self.latitude,
              let longitude = self.longitude else {
            throw LocationError.locationUnavailable
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func getAltitude() throws -> CLLocationDistance {
        guard let altitude = self.altitude else {
            throw LocationError.locationUnavailable
        }
        return altitude
    }
    
    func getHeading() throws -> CLLocationDirection {
        guard let headingDegrees = self.headingDegrees else {
            throw LocationError.headingUnavailable
        }
        return headingDegrees
    }
}
