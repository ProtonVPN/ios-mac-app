//
//  IPCWGService.swift
//  ProtonVPN WireGuard
//
//  Created by Jaroslav on 2021-08-02.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import ConnectionShared
import Foundation
import NEHelper
import VPNShared

class IPCWGService: XPCBaseService {
    private let keychain = TunnelKeychainImplementation()
    private let logViewHelper = LogViewHelper(logFilePath: FileManager.logFileURL?.path)
}

extension IPCWGService { // ProviderCommunication
    override func setCredentials(username _: String, password: String, completionHandler: @escaping (Bool) -> Void) {
        log("Will save config to keychain in old format.")

        guard let data = password.data(using: .utf8) else {
            log("Couldn't get UTF-8 data from wireguard config string; failing.")
            completionHandler(false)
            return
        }

        do {
            _ = try keychain.store(data)
        } catch {
            log("Failed to store credentials to the keychain: \(error)")
            completionHandler(false)
            return
        }

        log("New config saved (in old format).")
        completionHandler(true)
    }

    override func setConfigData(_ data: Data, completionHandler: @escaping (Bool) -> Void) {
        log("Will save config to keychain in serialized format.")

        do {
            _ = try keychain.store(data)
        } catch {
            log("Failed to store config to the keychain: \(error)")
            completionHandler(false)
            return
        }

        log("New config saved.")
        completionHandler(true)
    }

    override func getLogs(_ completionHandler: @escaping (Data?) -> Void) {
        log("Got getLogs XPC request")
        if Logger.global == nil {
            Logger.configureGlobal(tagged: "PROTON-WG", withFilePath: FileManager.logFileURL?.path)
        }
        guard let logViewHelper else {
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

    override func getInterfaceName(_ completionHandler: @escaping (String?) -> Void) {
        log("Got getInterfaceName XPC request")
        let interfaceName = WireguardNetworkInterface.interfaceName
        completionHandler(interfaceName)
    }
}
