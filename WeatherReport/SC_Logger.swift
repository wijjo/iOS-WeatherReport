//
//  SC_Logger.swift
//
//  Created by Steve Cooper on 1/1/15.
//  Copyright (c) 2015 Steve Cooper. All rights reserved.
//

import Foundation

/**
* Logging interface.
*/
protocol SC_LoggerInterface {

    func info(message: String)
    func error(message: String)
    func debug(message: String)
}

protocol SC_LoggerDelegate {
    func onError(message: String)
    func onInfo(message: String)
}

class SC_Logger: SC_LoggerInterface {

    var delegate: SC_LoggerDelegate?

    init(delegate: SC_LoggerDelegate? = nil) {
        self.delegate = delegate
    }

    func info(message: String) {
        println("INFO: \(message)")
        self.delegate?.onInfo(message)
    }

    func error(message: String) {
        println("ERROR: \(message)")
        self.delegate?.onError(message)
    }

    func debug(message: String) {
        println("DEBUG: \(message)")
    }
}