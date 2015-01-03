//
//  SavedData.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/14/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

// UIKit is just used for alert.
import UIKit
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
 * The external interface used by view controllers to access shared data.
 */
protocol SharedDataInterface {

    //=== Properties

    var state: SavedState { get }
    var weatherItems: [WeatherItem] { get }
    var logger: SCSCLoggerInterface! { get }

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
    func displayLog(type: SCSCMessageType, _ message: String)
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
class SharedData : NSObject, SharedDataInterface, CLLocationManagerDelegate, SCSCLocationDelegate, SCSCLoggerDelegate {

    var delegates = [SharedDataDelegate]()
    var weatherUpdateTimer: NSTimer?
    var weatherSource: WeatherSource!

    var location: SCSCLocation!

    // Private constructor used only by SharedDataSingleton.get().
    private override init() {
        super.init()
        self.logger = SCSCLogger(delegate: self)
        self.location = SCSCLocation(delegate: self, logger: self.logger)
        self.weatherSource = ForecastIO(logger: self.logger)
    }

    //TODO: Only load once for multiple views?
    func load() {
        let userDefs = NSUserDefaults.standardUserDefaults()
        if let dataRaw: AnyObject = userDefs.objectForKey("SavedState") {
            if let dataDict = dataRaw as? NSDictionary {
                self.logger.log(.Debug, "Loaded saved data.")
                self.state = SavedState(fromPersistentData: dataDict)
                self.weatherSource.location = self.state.placemark?.location
                self.handlePlaceUpdate(self.state.placemark, error: nil)
            } else {
                self.logger.log(.Warning, "Ignored bad saved state data.")
            }
        } else {
            self.logger.log(.Info, "Saved state data not found.")
        }
    }

    func save() {
        let userDefs = NSUserDefaults.standardUserDefaults()
        userDefs.setObject(self.state.persistentData, forKey: "SavedState")
    }

    //=== SharedDataInterface

    var state = SavedState()
    var weatherItems: [WeatherItem] = []
    let logger: SCSCLoggerInterface!

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
        self.logger.log(.Debug, "Requesting weather...")
        self.weatherSource.getWeather() { (items: [WeatherItem]) in
            self.weatherItems = items
            self.logger.log(.Debug, "Received weather data.")
            self.delegates.map { $0.didUpdateWeather(self.weatherItems) }
        }
    }

    func setPlaceToSearch(place: String) {
        self.location.addressGeocodeToCurrentLocation(place)
    }

    func setPlaceToCurrent() {
        self.location.startUpdatingLocation()
    }

    //=== SCSCLoggerInterface

    func scscLog(type: SCSCMessageType, _ message: String) {
        self.delegates.filter({$0.isActive()}).map({$0.displayLog(type, message)})
    }

    //=== SCSCLocationDelegate
    
    // Either placemark or error is non-nil, indicating success or failure
    func scscLocation(placemarkUpdated: CLPlacemark?, error: String?) {
        self.handlePlaceUpdate(placemarkUpdated, error: error)
        self.location.stopUpdatingLocation()
    }

    // Called when another type of error occurs.
    func scscLocation(otherError: String) {
        let alert = UIAlertView(title: "Location Error", message: otherError,
            delegate: nil, cancelButtonTitle: "Close")
        alert.show()
    }

    //=== NSTimer (weatherUpdateTimer)

    func weatherUpdateTimerFire(timer: NSTimer) {
        assert(timer === self.weatherUpdateTimer)
        self.updateWeather()
    }

    //=== Utility methods

    func handlePlaceUpdate(placemark: CLPlacemark?, error: String?) {
        self.state.placemark = placemark
        var place: SharedDataPlace?
        if self.state.placemark != nil {
            place = SharedDataPlace(placemark: self.state.placemark!)
        }
        self.delegates.map { $0.didUpdatePlace(place) }
        if let placemark = placemark {
            self.logger.log(.Debug, "Set place to \(placemark.name)")
        } else {
            if let error = error {
                self.logger.log(.Error, error)
            } else {
                self.logger.log(.Error, "Unknown error retrieving place.")
            }
        }
        self.weatherSource.location = placemark?.location
        self.updateWeather()
    }
}
