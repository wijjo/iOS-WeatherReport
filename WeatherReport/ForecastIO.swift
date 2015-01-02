//
//  ForecastIO.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/20/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import Foundation
import CoreLocation

// https://developer.forecast.io/docs/v2
private let baseURL = "https://api.forecast.io/forecast"

let useCannedData = false
let cannedData: NSDictionary = [
    "apparentTemperature": "44.23",
    "cloudCover": "0.53",
    "dewPoint": "40.83",
    "humidity": "0.84",
    "icon": "partly-cloudy-day",
    "nearestStormBearing": 345,
    "nearestStormDistance": 155,
    "ozone": "285.65",
    "precipIntensity": 0,
    "precipProbability": 0,
    "pressure": "1026.89",
    "summary": "Partly Cloudy",
    "temperature": "45.49",
    "time": 1419783003,
    "visibility": "8.52",
    "windBearing": 33,
    "windSpeed": "2.14",
]

class ForecastIO : WeatherSourceBase {

    override func getWeather(completionHandler: (items: [WeatherItem]) -> ()) {
        if !useCannedData {
            let session = NSURLSession.sharedSession()
            if let url = forecastURL() {
                self.log(.Debug, "URL: \(url.absoluteString)")
                var request = NSMutableURLRequest(URL: url)
                request.HTTPMethod = "GET"
                let task = session.dataTaskWithRequest(request) { data, response, error in
                    var items: [WeatherItem] = []
                    if let httpResponse = response as? NSHTTPURLResponse {
                        if let error = error {
                            self.log(.Error, error.localizedDescription)
                        } else if httpResponse.statusCode != 200 {
                            self.log(.Error, "HTTP error \(httpResponse.statusCode)")
                        } else {
                            if let result = NSJSONSerialization.JSONObjectWithData(data,
                                options: NSJSONReadingOptions.allZeros, error: nil) as? NSDictionary {
                                if let currently = result["currently"] as? NSDictionary {
                                    items = self.forecastItems(currently)
                                } else {
                                    self.log(.Error, "failed to access current conditions")
                                }
                            }
                        }
                    }
                    completionHandler(items: items)
                }
                task.resume()
            }
            else {
                self.log(.Error, "failed to construct URL")
            }
        } else {
            let items = self.forecastItems(cannedData)
            completionHandler(items: items)
        }
    }

    func forecastItems(dict: NSDictionary) -> [WeatherItem] {

        var itemBuilder = WeatherItemBuilder(dict)

        var fieldBuilder = itemBuilder.makeItem("Summary", symbol: dict["icon"] as? String)
        fieldBuilder.string("summary")

        fieldBuilder = itemBuilder.makeItem("Time")
        fieldBuilder.unixDate("time")

        fieldBuilder = itemBuilder.makeItem("Temperature")
        fieldBuilder.degrees("temperature")
        fieldBuilder.parenthesize()
        fieldBuilder.label("feels like")
        fieldBuilder.degrees("apparentTemperature")

        fieldBuilder = itemBuilder.makeItem("Precipitation", symbol: dict["precipType"] as? String)
        fieldBuilder.string("precipType")
        fieldBuilder.percent("precipProbability")

        fieldBuilder = itemBuilder.makeItem("Wind")
        fieldBuilder.mph("windSpeed")
        fieldBuilder.parenthesize()
        fieldBuilder.label("from")
        fieldBuilder.bearing("windBearing")

        fieldBuilder = itemBuilder.makeItem("Humidity")
        fieldBuilder.percent("humidity")

        fieldBuilder = itemBuilder.makeItem("Pressure")
        fieldBuilder.millibars("pressure")

        fieldBuilder = itemBuilder.makeItem("Cloud Cover")
        fieldBuilder.percent("cloudCover")

        fieldBuilder = itemBuilder.makeItem("Visibility")
        fieldBuilder.miles("visibility")

        fieldBuilder = itemBuilder.makeItem("Dew Point")
        fieldBuilder.degrees("dewPoint")

        return itemBuilder.toItems()
    }

    func forecastURL() -> NSURL? {
        if let coord = self.location?.coordinate {
            let apiKey = forecastIOAPIKey
            return NSURL(string: "\(baseURL)/\(apiKey)/\(coord.latitude),\(coord.longitude)")
        }
        return nil
    }

    func forecastURL(date: NSDate) -> NSURL? {
        if let url = forecastURL() {
            let formatter = NSDateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let dateString = formatter.stringFromDate(date)
            url.URLByAppendingPathComponent(",\(dateString)")
            return url
        }
        return nil
    }

    func log(type: SCSCMessageType, _ message: String) {
        self.logger.log(type, "Forecast.IO: \(message)")
    }
}
