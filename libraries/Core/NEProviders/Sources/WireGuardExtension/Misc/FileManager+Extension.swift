// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import Domain
import Foundation
import os.log
import WireGuardLogging

extension FileManager {
    static var appGroupId: String {
        DomainConstants.AppGroups.main
    }

    private static var sharedFolderURL: URL? {
        #if os(macOS)
            return FileManager.default.temporaryDirectory

        #else
            guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FileManager.appGroupId) else {
                wg_log(.error, message: "Cannot obtain shared folder URL for appGroupId \(FileManager.appGroupId) ")
                return nil
            }
            return sharedFolderURL
        #endif
    }

    static var logFileURL: URL? {
        sharedFolderURL?.appendingPathComponent("WireGuard.bin")
    }

    static var logTextFileURL: URL? {
        sharedFolderURL?.appendingPathComponent("WireGuard.log")
    }

    static var networkExtensionLastErrorFileURL: URL? {
        sharedFolderURL?.appendingPathComponent("last-error.txt")
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
