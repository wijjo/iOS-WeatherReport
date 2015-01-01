//
//  WeatherSource.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/14/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import Foundation
import CoreLocation

protocol WeatherSource {
    var location: CLLocation? { get set }

    func getWeather(completionHandler: (items: [WeatherItem]) -> ())
}

class WeatherSourceBase : WeatherSource {

    let logger: SC_LoggerInterface
    var location: CLLocation?

    init(logger: SC_LoggerInterface) {
        self.logger = logger
    }

    func getWeather(completionHandler: (items: [WeatherItem]) -> ()) {
        completionHandler(items: [])
        self.logger.error("Weather source implementation is incomplete.")
    }
}
