//
//  iPCOvpnService.swift
//  ProtonVPN OpenVPN
//
//  Created by Jaroslav on 2021-08-09.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import TunnelKit
import OSLog

class IPCOvpnService: XPCBaseService {
    
}

extension IPCOvpnService { // ProviderCommunication
    
    override func setCredentials(username: String, password: String, completionHandler: @escaping (Bool) -> Void) {
        let keychain = Keychain(group: nil)
        do {
            let currentPassword = try? keychain.password(for: username)
            guard currentPassword != password else {
                completionHandler(true)
                return
            }
            
            try keychain.set(password: password, for: username)
            log("PacketTunnelProvider new password saved")
            completionHandler(true)
            
        } catch {
            log("PacketTunnelProvider can't write password to keychain: \(error)")
            completionHandler(false)
        }
    }

    override func getLogs(_ completionHandler: @escaping (Data?) -> Void) {
        guard #available(macOS 12.0, *) else {
            // `OSLogStore(scope: .currentProcessIdentifier)` is not available on macOS 10.15, so we have to use logs from the file.
            // This can be deleted when app no longer supports macOS 10.15.
            guard let logsContent = try? String(contentsOf: LogSettings.logFileUrl) else {
                completionHandler(nil)
                return
            }
            completionHandler(logsContent.data(using: .utf8))
            return
        }

        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 1)

            let entries = try store.getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == LogSettings.osLogSubsystem }
                .map { "\(dateFormatter.string(from: $0.date)) | \($0.level.stringValue.uppercased()) | \($0.composedMessage)" }
            let result = entries.joined(separator: "\n")
            completionHandler(result.data(using: .utf8))

        } catch {
            log("Error reading logs: \(error)")
            completionHandler(nil)
        }

    }
}

extension OSLogEntryLog.Level {
    var stringValue: String {
        switch self {
        case .undefined:
            return "Undefined"
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .notice:
            return "Notice"
        case .error:
            return "Error"
        case .fault:
            return "Fault"
        }
    }
}
