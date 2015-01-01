//
//  ViewController.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/14/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController,
    UITextFieldDelegate,
    UITableViewDelegate,
    UITableViewDataSource,
    SharedDataDelegate {

    //=== Outlets
    
    @IBOutlet weak var uiPropertyTable: UITableView!
    @IBOutlet weak var uiSearchText: UITextField!
    
    //=== Properties

    // Initialized in viewDidLoad() - don't use before then!
    var sharedData: SharedDataInterface!
    var logger: SC_LoggerInterface!
    var currentPlace: SharedDataPlace?
    var weatherItems: [WeatherItem] = []
    var viewIsActive = true;

    //=== UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "NameValueSymbolCell", bundle: nil)
        self.uiPropertyTable.registerNib(nib, forCellReuseIdentifier: "nameValueSymbolCell")
        self.sharedData = SharedDataSingleton.get(self)
        self.logger = self.sharedData.logger
        self.sharedData.load()
        if let placemark = self.sharedData.state.placemark {
            self.logger.info("Loaded location \(placemark.name).")
        } else {
            self.sharedData.setPlaceToCurrent()
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        viewIsActive = true
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsActive = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Close keyboard when touch happens outside fields.
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
    }

    //=== Current location button

    @IBAction func currentLocationButtonAction(sender: AnyObject) {
        self.sharedData.setPlaceToCurrent()
    }

    //=== Search button

    @IBAction func searchButtonAction(sender: AnyObject) {
        self.searchForPlace()
    }

    //=== UITextFieldDelegate

    func textFieldDidBeginEditing(textField: UITextField) {
        self.uiSearchText.selectAll(nil)
        self.uiSearchText.placeholder = "Place to search for..."
    }

    func textFieldDidEndEditing(textField: UITextField) {
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.searchForPlace()
        return true
    }

    //=== SharedDataDelegate

    func didUpdatePlace(place: SharedDataPlace?) {
        self.currentPlace = place
        if let place = place {
            self.uiSearchText.text = place.oneLineAddress
            self.logger.info("Place: \(self.uiSearchText.text)")
        } else {
            self.logger.info("Place: (none)")
        }
        self.sharedData.save()
        self.uiPropertyTable.reloadData()
    }

    func didUpdateWeather(items: [WeatherItem]) {
        self.weatherItems = []
        if let place = self.currentPlace {
            self.weatherItems.append(WeatherItem("Location", place.oneLineAddress, nil))
        }
        self.weatherItems.extend(items)
        // Trigger the reload from the main thread.
        dispatch_async(dispatch_get_main_queue()) {
            self.uiPropertyTable.reloadData()
        }
    }

    func displayInfo(message: String) {
    }

    func displayError(message: String) {
    }

    func isActive() -> Bool {
        return self.viewIsActive
    }

    //=== UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numRows = self.weatherItems.count
        return numRows
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.uiPropertyTable.dequeueReusableCellWithIdentifier("nameValueSymbolCell")
            as NameValueSymbolCell
        cell.loadData(self.weatherItems[indexPath.row], logger: self.logger)
        return cell
    }

    //=== Powered by Forecast badge.

    @IBAction func poweredByForecastButtonAction(sender: AnyObject) {
        if let url = NSURL(string: "http://forecast.io/") {
            UIApplication.sharedApplication().openURL(url)
        } else {
            self.logger.error("NSURL creation failed for Forecast badge link.")
        }
    }

    //=== Utility methods
    
    func searchForPlace() {
        self.view.endEditing(true)
        if !self.uiSearchText.text.isEmpty {
            self.sharedData.setPlaceToSearch(self.uiSearchText.text)
        }
    }

    func getCurrentLocation() {
        self.uiSearchText.placeholder = "Searching for current location..."
        self.sharedData.setPlaceToCurrent()
    }
}
