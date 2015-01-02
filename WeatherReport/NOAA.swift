//
//  NOAA.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/14/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import Foundation
import CoreLocation

// Append <METAR station>.xml
let conditionsBaseURL = "http://www.weather.gov/xml/current_obs/"

class NOAA : WeatherSourceBase {

    override func getWeather(completionHandler: (items: [WeatherItem]) -> ()) {
        completionHandler(items: [])
        self.logger.log(.Error, "NOAA weather source is not implemented.")
    }
}
