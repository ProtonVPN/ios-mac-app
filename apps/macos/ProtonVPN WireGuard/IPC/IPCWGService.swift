//
//  XPCWGService.swift
//  ProtonVPN WireGuard
//
//  Created by Jaroslav on 2021-08-02.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class IPCWGService: XPCBaseService {
    private let logViewHelper = LogViewHelper(logFilePath: FileManager.logFileURL?.path)
}

extension IPCWGService { // ProviderCommunication
    
    override func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void) {
        let wgConfig = password
        log("Will save wg config ")
        if Keychain.saveWgConfig(value: wgConfig) {
            log("New config saved.")
            completionHandler(true)
        } else {
            log("New config save error.")
            completionHandler(false)
        }
    }
    
    override func getLogs(_ completionHandler: @escaping (Data?) -> Void) {
        log("Got getLogs XPC request")
        if Logger.global == nil {
            Logger.configureGlobal(tagged: "PROTON-WG", withFilePath: FileManager.logFileURL?.path)
        }
        guard let logViewHelper = logViewHelper else {
            completionHandler(nil)
            return
        }
        logViewHelper.fetchLogEntriesSinceLastFetch { fetchedLogEntries in
            var logContent = ""
            for entry in fetchedLogEntries {
                logContent += "\(entry.text())\n"
            }
            completionHandler(logContent.data(using: .utf8))
        }
    }
    
}
