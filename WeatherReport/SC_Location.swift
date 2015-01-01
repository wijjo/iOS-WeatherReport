//
//  SC_Location.swift
//
//  Created by Steve Cooper on 1/1/15.
//  Copyright (c) 2015 Steve Cooper. All rights reserved.
//

import Foundation

import CoreLocation

protocol SC_LocationDelegate {
    func didUpdatePlacemark(placemark: CLPlacemark?, error: String?)
}

/**
* Location utility class.
*/
class SC_Location : NSObject, CLLocationManagerDelegate {

    // Initialize and provide a location manager on demand, if needed.
    var locationManagerCached: CLLocationManager?
    var locationManager: CLLocationManager {
        if self.locationManagerCached == nil {
            self.locationManagerCached = CLLocationManager()
            self.locationManagerCached!.delegate = self
            self.locationManagerCached!.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManagerCached!.requestWhenInUseAuthorization()
        }
        return self.locationManagerCached!
    }

    let delegate: SC_LocationDelegate
    let logger: SC_LoggerInterface

    init(delegate: SC_LocationDelegate, logger: SC_LoggerInterface) {
        self.delegate = delegate
        self.logger = logger
    }

    func startUpdatingLocation() {
        self.locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        self.locationManager.stopUpdatingLocation()
    }

    //=== CLLocationManagerDelegate

    // Called when the current location is successfully retrieved.
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        // Just use the first location for now.
        self.locationManager.stopUpdatingLocation()
        if !locations.isEmpty {
            self.logger.debug("Received \(locations.count) location(s) from location manager.")
            if let location = locations[0] as? CLLocation {
                self.reverseGeocodeLocation(location)
            } else {
                self.delegate.didUpdatePlacemark(nil, error: "Received bad location from location manager.")
            }
        } else {
            self.delegate.didUpdatePlacemark(nil, error: "Received no locations from location manager.")
        }
    }

    // Called when an error occurs while retrieving the current location.
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        self.delegate.didUpdatePlacemark(nil, error: error.localizedDescription)
    }

    //=== Utility methods

    // Curry with an error tag for use as a CLGeocoder lookup completion handler.
    func geocoderCompletionHandler(tag: String) (placemarks: [AnyObject]!, error: NSError!) {
        if placemarks != nil && placemarks.count > 0 {
            self.logger.debug("Received \(placemarks.count) placemark(s) from geocoder.")
            // Only use the first placemark.
            if let placemark = placemarks[0] as? CLPlacemark {
                self.delegate.didUpdatePlacemark(placemark, error: nil)
            } else {
                self.delegate.didUpdatePlacemark(nil, error: "\(tag) error: bad placemark")
            }
        }
        else {
            if error != nil {
                self.delegate.didUpdatePlacemark(nil, error: "\(tag) error: \(error.description)")
            } else {
                self.delegate.didUpdatePlacemark(nil, error: "\(tag) error: unknown error")
            }
        }
    }

    func addressGeocodeToCurrentLocation(placeName: String) {
        let geocoder = CLGeocoder()
        self.logger.debug("Geocoding address '\(placeName)'...")
        geocoder.geocodeAddressString(placeName,
            completionHandler: self.geocoderCompletionHandler("Lookup"))
    }

    func reverseGeocodeLocation(location: CLLocation) {
        let geocoder = CLGeocoder()
        self.logger.debug("Reverse geocoding location...")
        geocoder.reverseGeocodeLocation(location,
            completionHandler: self.geocoderCompletionHandler("Reverse"))
    }
}

let stateAbbreviations = [
    "alabama": "AL",
    "alaska": "AK",
    "arizona": "AZ",
    "arkansas": "AR",
    "california": "CA",
    "colorado": "CO",
    "connecticut": "CT",
    "delaware": "DE",
    "district of columbia": "DC",
    "florida": "FL",
    "georgia": "GA",
    "hawaii": "HI",
    "idaho": "ID",
    "illinois": "IL",
    "indiana": "IN",
    "iowa": "IA",
    "kansas": "KS",
    "kentucky": "KY",
    "louisiana": "LA",
    "maine": "ME",
    "maryland": "MD",
    "massachusetts": "MA",
    "michigan": "MI",
    "minnesota": "MN",
    "mississippi": "MS",
    "missouri": "MO",
    "montana": "MT",
    "nebraska": "NE",
    "nevada": "NV",
    "new hampshire": "NH",
    "new jersey": "NJ",
    "new mexico": "NM",
    "new york": "NY",
    "north carolina": "NC",
    "north dakota": "ND",
    "ohio": "OH",
    "oklahoma": "OK",
    "oregon": "OR",
    "pennsylvania": "PA",
    "rhode island": "RI",
    "south carolina": "SC",
    "south dakota": "SD",
    "tennessee": "TN",
    "texas": "TX",
    "utah": "UT",
    "vermont": "VT",
    "virginia": "VA",
    "washington": "WA",
    "west virginia": "WV",
    "wisconsin": "WI",
    "wyoming": "WY",
]
