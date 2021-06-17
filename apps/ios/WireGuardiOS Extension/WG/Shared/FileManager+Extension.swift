// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

extension FileManager {
    
    static private var teamId: String {
        return Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    }
    
    static var appGroupId: String? {
//        #if os(iOS)
//        let appGroupIdInfoDictionaryKey = "group.ch.protonmail.vpn"
//        #elseif os(macOS)
//        let appGroupIdInfoDictionaryKey = "group.ch.protonmail.vpn"
//        #else
//        #error("Unimplemented")
//        #endif
//        return Bundle.main.object(forInfoDictionaryKey: appGroupIdInfoDictionaryKey) as? String
        
        return "group.ch.protonvpn.mac"
    }
    
    private static var sharedFolderURL: URL? {
        guard let appGroupId = FileManager.appGroupId else {
            os_log("Cannot obtain app group ID from bundle", log: OSLog.default, type: .error)
            return nil
        }
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            wg_log(.error, message: "Cannot obtain shared folder URL")
            return nil
        }
        return sharedFolderURL
    }

    static var logFileURL: URL? {
        return sharedFolderURL?.appendingPathComponent("tunnel-log.bin")
    }

    static var networkExtensionLastErrorFileURL: URL? {
        return sharedFolderURL?.appendingPathComponent("last-error.txt")
    }

    static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            return false
        }
        return true
    }
}
