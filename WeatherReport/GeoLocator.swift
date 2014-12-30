//
//  GeoLocator.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/20/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import Foundation
import CoreLocation

struct GeoLocation {
    let latitude: Int
    let longitude: Int
}

struct GeoLocationResults {
    let coordinates: GeoLocation?
    let error: String?
}

class GeoLocator : NSObject, CLLocationManagerDelegate {

    let locMgr = CLLocationManager()

    override init() {
        super.init()
        self.locMgr.delegate = self
    }

    func currentLocation() {
        self.locMgr.desiredAccuracy = kCLLocationAccuracyBest
        self.locMgr.requestWhenInUseAuthorization()
        self.locMgr.startUpdatingLocation()
    }

    //=== CLLocationManagerDelegate

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        for location in locations as [CLLocation] {
            println(location.description)
            self.locMgr.stopUpdatingLocation()
        }
    }

    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        println("Error while updating location: \(error.localizedDescription)")
    }

}
