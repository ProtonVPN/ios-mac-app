//
//  LogsViewModel.swift
//  ProtonVPN - Created on 12.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import vpncore

struct LogsViewModel {
    
    let title: String
    let logFile: URL
    
    var logs: String {
        do {
            return try String(contentsOf: logFile, encoding: .ascii)
        } catch {
            log.error("Error reading log file (\(logFile): \(error)", category: .ui)
            return ""
        }
    }
    
}
