//
//  LogFilesProvider.swift
//  Core
//
//  Created by Jaroslav on 2021-06-04.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

/// Provides all available log files together with their names
public protocol LogFilesProvider {
    var logFiles: [(String, URL?)] { get }
}

public protocol LogFilesProviderFactory {
    func makeLogFilesProvider() -> LogFilesProvider
}

/// Default implementation that lists all possible log files
public class DefaultLogFilesProvider: LogFilesProvider {
    public var logFiles: [(String, URL?)]
    
    public init(vpnManager: VpnManagerProtocol, logFileManager: LogFileManager, appLogFilename: String) {
        logFiles = [
            (LocalizedString.applicationLogs, logFileManager.getFileUrl(named: appLogFilename)), // Application logs
            (LocalizedString.applicationLogs, vpnManager.logFile(for: .ike)), // Empty for apple's ikev2 implementation
            (LocalizedString.openVpnLogs, vpnManager.logFile(for: .openVpn(.undefined))),
            (LocalizedString.wireguardLogs, vpnManager.logFile(for: .wireGuard))
        ]
    }
}
