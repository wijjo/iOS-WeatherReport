//
//  SavedData.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/14/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import Foundation
import CoreLocation

/**
 * Manages a SharedData singleton.
 *
 * View controllers use this to get access to shared data.
 * Call SharedDataSingleton.get() to get the instance.
 */
class SharedDataSingleton {

    // Get the singleton SharedData instance.
    // Provide the protocol so that the public interface is clearer.
    class func get(delegate: SharedDataDelegate) -> SharedDataInterface {
        struct Static {
            static var instance: SharedData?
            static var token: dispatch_once_t = 0
        }

        dispatch_once(&Static.token) {
            Static.instance = SharedData()
        }

        Static.instance!.delegates.append(delegate)

        return Static.instance!
    }
}

/**
 * Logging interface.
 */
protocol SharedLogger {

    func info(message: String)
    func error(message: String)
    func debug(message: String)
}

/**
 * The external interface used by view controllers to access shared data.
 */
protocol SharedDataInterface: SharedLogger {

    //=== Properties

    var state: SavedState { get }
    var weatherItems: [WeatherItem] { get }

    //=== Methods

    func updateWeather()
    func setPlaceToSearch(place: String)
    func setPlaceToCurrent()
    func load()
    func save()
}

class SharedDataPlace {
    let placemark: CLPlacemark

    init(placemark: CLPlacemark) {
        self.placemark = placemark
    }

    var oneLineAddress: String {
        get {
            var retAddress = ""
            func add(text: String?, withComma: Bool = true, abbreviations: [String: String]? = nil) {
                if let text = text {
                    if !retAddress.isEmpty {
                        if withComma {
                            retAddress += ","
                        }
                        retAddress += " "
                    }
                    if let dict = abbreviations {
                        if let abbreviation = dict[text.lowercaseString] {
                            retAddress += abbreviation
                        } else {
                            retAddress += text
                        }
                    } else {
                        retAddress += text
                    }
                }
            }
            add(self.placemark.subThoroughfare)
            add(self.placemark.thoroughfare, withComma: false)
            add(self.placemark.locality)
            add(self.placemark.administrativeArea, abbreviations: stateAbbreviations)
            add(self.placemark.ISOcountryCode)
            add(self.placemark.postalCode, withComma: false)
            return retAddress
        }
    }

    var shortName: String {
        return self.placemark.name
    }
}

/**
 * The call-back event protocol implemented by view controllers.
 */
protocol SharedDataDelegate {
    func didUpdatePlace(place: SharedDataPlace?)
    func didUpdateWeather(items: [WeatherItem])
    func displayInfo(message: String)
    func displayError(message: String)
    func isActive() -> Bool
}

/**
 * Saved state (persistent) data.
 */
class SavedState: NSObject {
    var placemark: CLPlacemark?
    let weatherUpdateMinutes: Int = 60

    var persistentData: NSDictionary {
        get {
            var dict = [String: AnyObject]()
            if let placemark = self.placemark {
                let placemarkData = NSKeyedArchiver.archivedDataWithRootObject(placemark)
                dict["placemark"] = placemarkData
            }
            dict["weatherUpdateMinutes"] = self.weatherUpdateMinutes
            return NSDictionary(dictionary: dict)
        }
    }

    override init() {
    }

    init(other: SavedState) {
        self.placemark = other.placemark
        self.weatherUpdateMinutes = other.weatherUpdateMinutes
    }

    init(fromPersistentData: NSDictionary) {
        if let placemarkData = fromPersistentData["placemark"] as? NSData {
            if let placemark = NSKeyedUnarchiver.unarchiveObjectWithData(placemarkData) as? CLPlacemark {
                self.placemark = placemark
            }
        }
        if let weatherUpdateMinutes = fromPersistentData["weatherUpdateMinutes"] as? Int {
            self.weatherUpdateMinutes = weatherUpdateMinutes
        }
    }
}

/**
 * Shared data implementation class. Not for external consumption.
 */
class SharedData : NSObject, SharedDataInterface, CLLocationManagerDelegate {

    var delegates = [SharedDataDelegate]()
    var weatherUpdateTimer: NSTimer?
    var weatherSource: WeatherSource!

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

    // Private constructor used only by SharedDataSingleton.get().
    private override init() {
        super.init()
        self.weatherSource = ForecastIO(logger: self)
    }

    //TODO: Only load once for multiple views?
    func load() {
        let userDefs = NSUserDefaults.standardUserDefaults()
        if let dataRaw: AnyObject = userDefs.objectForKey("SavedState") {
            if let dataDict = dataRaw as? NSDictionary {
                self.debug("Loaded saved data.")
                self.state = SavedState(fromPersistentData: dataDict)
                self.weatherSource.location = self.state.placemark?.location
                self.updatePlace(self.state.placemark, error: nil)
            } else {
                self.info("Ignored bad saved state data.")
            }
        } else {
            self.info("Saved state data not found.")
        }
    }

    func save() {
        let userDefs = NSUserDefaults.standardUserDefaults()
        userDefs.setObject(self.state.persistentData, forKey: "SavedState")
    }

    //=== SharedDataInterface

    var state = SavedState()
    var weatherItems: [WeatherItem] = []

    func updateWeather() {
        // Start the timer on the first update.
        if self.weatherUpdateTimer == nil {
            self.weatherUpdateTimer = NSTimer.scheduledTimerWithTimeInterval(
                Double(self.state.weatherUpdateMinutes) * 60.0,
                target: self,
                selector: Selector("weatherUpdateTimerFire"),
                userInfo: nil,
                repeats: true)
        }
        self.debug("Requesting weather...")
        self.weatherSource.getWeather() { (items: [WeatherItem]) in
            self.weatherItems = items
            self.debug("Received weather data.")
            self.delegates.map { $0.didUpdateWeather(self.weatherItems) }
        }
    }

    func setPlaceToSearch(place: String) {
        self.addressGeocodeToCurrentLocation(place)
    }

    func setPlaceToCurrent() {
        self.locationManager.startUpdatingLocation()
    }

    func info(message: String) {
        println("INFO: \(message)")
        self.delegates.filter({$0.isActive()}).map({$0.displayInfo(message)})
    }

    func error(message: String) {
        println("ERROR: \(message)")
        self.delegates.filter({$0.isActive()}).map({$0.displayError(message)})
    }

    func debug(message: String) {
        println("DEBUG: \(message)")
    }

    //=== NSTimer (weatherUpdateTimer)

    func weatherUpdateTimerFire(timer: NSTimer) {
        assert(timer === self.weatherUpdateTimer)
        self.updateWeather()
    }

    //=== CLLocationManagerDelegate

    // Called when the current location is successfully retrieved.
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        // Just use the first location for now.
        self.locationManager.stopUpdatingLocation()
        if !locations.isEmpty {
            self.debug("Received \(locations.count) location(s) from location manager.")
            if let location = locations[0] as? CLLocation {
                self.reverseGeocodeLocation(location)
            } else {
                self.updatePlace(nil, error: "Received bad location from location manager.")
            }
        } else {
            self.updatePlace(nil, error: "Received no locations from location manager.")
        }
    }

    // Called when an error occurs while retrieving the current location.
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        self.state.placemark = nil
        self.updatePlace(nil, error: error.localizedDescription)
    }

    //=== Utility methods

    // Curry with an error tag for use as a CLGeocoder lookup completion handler.
    func geocoderCompletionHandler(tag: String) (placemarks: [AnyObject]!, error: NSError!) {
        if placemarks != nil && placemarks.count > 0 {
            self.debug("Received \(placemarks.count) placemark(s) from geocoder.")
            // Only use the first placemark.
            if let placemark = placemarks[0] as? CLPlacemark {
                self.updatePlace(placemark, error: nil)
            } else {
                self.updatePlace(nil, error: "\(tag) error: bad placemark")
            }
        }
        else {
            if error != nil {
                self.updatePlace(nil, error: "\(tag) error: \(error.description)")
            } else {
                self.updatePlace(nil, error: "\(tag) error: unknown error")
            }
        }
    }

    func addressGeocodeToCurrentLocation(placeName: String) {
        self.state.placemark = nil
        let geocoder = CLGeocoder()
        self.debug("Geocoding address '\(placeName)'...")
        geocoder.geocodeAddressString(placeName,
            completionHandler: self.geocoderCompletionHandler("Lookup"))
    }

    func reverseGeocodeLocation(location: CLLocation) {
        self.state.placemark = nil
        let geocoder = CLGeocoder()
        self.debug("Reverse geocoding location...")
        geocoder.reverseGeocodeLocation(location,
            completionHandler: self.geocoderCompletionHandler("Reverse"))
    }

    func updatePlace(placemark: CLPlacemark?, error: String?) {
        self.state.placemark = placemark
        var place: SharedDataPlace?
        if self.state.placemark != nil {
            place = SharedDataPlace(placemark: self.state.placemark!)
        }
        self.delegates.map { $0.didUpdatePlace(place) }
        if let placemark = placemark {
            self.debug("Set place to \(placemark.name)")
        } else {
            if let error = error {
                self.error(error)
            } else {
                self.error("Unknown error retrieving place.")
            }
        }
        self.weatherSource.location = placemark?.location
        self.updateWeather()
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
