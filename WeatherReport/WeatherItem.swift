//
//  WeatherItem.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/28/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import Foundation

let bearings = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

struct WeatherItem {
    var label: String
    var text: String
    var symbol: String?

    init(_ label: String, _ text: String, _ symbol: String?) {
        self.label = label
        self.text = text
        self.symbol = symbol
    }

    init(_ label: String, _ text: String) {
        self.label = label
        self.text = text
    }
}

// Utility for building weather items with single or multi-field values from a dictionary.
class WeatherItemBuilder {
    let d: NSDictionary

    struct FieldSpec {
        let label: String
        let symbol: String?
        let builder: WeatherFieldBuilder
    }
    var fieldSpecs: [FieldSpec] = []

    init(_ d: NSDictionary) {
        self.d = d
    }

    func makeItem(label: String, symbol: String? = nil) -> WeatherFieldBuilder {
        let fieldSpec = FieldSpec(label: label, symbol: symbol, builder: WeatherFieldBuilder(d))
        self.fieldSpecs.append(fieldSpec)
        return fieldSpec.builder
    }

    func toItems() -> [WeatherItem] {
        var items: [WeatherItem] = []
        for fieldSpec in self.fieldSpecs {
            items.append(WeatherItem(fieldSpec.label, fieldSpec.builder.toString(), fieldSpec.symbol))
        }
        return items
    }
}

func formatDouble(value: Double?, precision: Int = 2) -> String? {
    if let v = value {
        if precision == 0 {
            let i = Int(v + 0.5)
            return "\(i)"
        }
        let format = "%.\(precision)f"
        return NSString(format: format, v)
    }
    return nil
}

// Used to build each individual multi-field items.
class WeatherFieldBuilder {
    let d: NSDictionary
    var f: [String] = []
    var wrapParens = false
    var itemLabel: String?
    var itemSymbol: String?
    var fieldLabel: String?

    init(_ d: NSDictionary) {
        self.d = d
    }

    func parenthesize() {
        self.wrapParens = true
    }

    func label(fieldLabel: String) {
        self.fieldLabel = fieldLabel
    }

    private func resetField() {
        self.wrapParens = false
        self.fieldLabel = nil
    }

    func appendValue(valueString: String) {
        var before = self.wrapParens ? "(" : ""
        var after = self.wrapParens ? ")" : ""
        var labelString = self.fieldLabel != nil ? "\(self.fieldLabel!) " : ""
        self.f.append("\(before)\(labelString)\(valueString)\(after)")
    }

    func getInt(key: String) -> Int? {
        if let v = self.d[key] as? Int {
            return v
        }
        if let v = (self.d[key] as? String)?.toInt() {
            return v
        }
        return nil
    }

    func getDouble(key: String) -> Double? {
        if let v = self.d[key] as? Double {
            return v
        }
        if let v = self.d[key] as? NSString {
            return v.doubleValue
        }
        return nil
    }

    func getString(key: String) -> String? {
        return self.d[key] as? String
    }

    func unixDate(key: String) {
        if let v = self.getInt(key) {
            let formatter = NSDateFormatter()
            formatter.dateFormat = "HH:mm:ss zzz MM-dd-yyyy"
            self.appendValue(
                formatter.stringFromDate(NSDate(timeIntervalSince1970: NSTimeInterval(v))))
        }
        self.resetField()
    }

    func degrees(key: String, precision: Int = 0) {
        if let v = formatDouble(self.getDouble(key), precision: precision) {
            self.appendValue("\(v)˚")
        }
        self.resetField()
    }

    func percent(key: String, precision: Int = 0) {
        if let v = self.getDouble(key) {
            if let percentString = formatDouble(v * 100.0, precision: precision) {
                self.appendValue("\(percentString)%")
            }
        }
        self.resetField()
    }

    func string(key: String) {
        if let v = self.getString(key) {
            self.appendValue(v)
        }
        self.resetField()
    }

    func mph(key: String, precision: Int = 0) {
        if let v = formatDouble(self.getDouble(key), precision: precision) {
            self.appendValue("\(v) MPH")
        }
        self.resetField()
    }

    func miles(key: String, precision: Int = 0) {
        if let v = formatDouble(self.getDouble(key), precision: precision) {
            self.appendValue("\(v) miles")
        }
        self.resetField()
    }

    func millibars(key: String, precision: Int = 0) {
        if let v = formatDouble(self.getDouble(key), precision: precision) {
            self.appendValue("\(v) millibars")
        }
        self.resetField()
    }

    func bearing(key: String) {
        if let degrees = self.getDouble(key) {
            let bearingDivisor = 360.0 / Double(bearings.count)
            // Formula rounds so that bearing regions surround the precise directions.
            let index = Int((degrees + (bearingDivisor / 2.0)) / bearingDivisor) % bearings.count
            self.appendValue(bearings[index])
        }
        self.resetField()
    }

    func toString() -> String {
        return " ".join(self.f)
    }
}
