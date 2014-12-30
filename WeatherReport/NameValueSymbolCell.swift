//
//  NameValueSymbolCell.swift
//  WeatherReport
//
//  Created by Steve Cooper on 12/14/14.
//  Copyright (c) 2014 Steve Cooper. All rights reserved.
//

import UIKit

class NameValueSymbolCell : UITableViewCell {
    @IBOutlet var uiName: UILabel!
    @IBOutlet var uiValue: UILabel!
    @IBOutlet var uiSymbol: UIImageView!
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func loadData(item: WeatherItem, logger: SharedLogger) {
        self.uiName.text = "\(item.label):"
        self.uiValue.text = item.text
        var image: UIImage?
        if let symbol = item.symbol {
            image = UIImage(named: symbol)
            if image == nil {
                logger.error("Failed to load symbol image '\(symbol)'.")
            }
        }
        self.uiSymbol.image = image
    }
}
