// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

extension FileManager {

    static var appGroupId: String {
        return WGConstants.appGroupId
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
        return sharedFolderURL?.appendingPathComponent("WireGuard.bin")
    }

    static var logTextFileURL: URL? {
        return sharedFolderURL?.appendingPathComponent("WireGuard.log")
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
