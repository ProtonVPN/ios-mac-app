// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import Domain
import Foundation
import os.log
import PMLogger
import WireGuardLogging

extension FileManager {
    private static func ensureParentDirectoryExists(for fileURL: URL?) -> URL? {
        guard let fileURL else { return nil }

        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return fileURL
        } catch {
            wg_log(.error, message: "Cannot create WireGuard logs directory for file \(fileURL.path): \(error)")
            return nil
        }
    }

    static var appGroupId: String {
        DomainConstants.AppGroups.main
    }

    static var logFileURL: URL? {
        let url = ensureParentDirectoryExists(for: WireGuardLogPaths.binaryLogURL(appGroup: appGroupId))
        if url == nil {
            wg_log(.error, message: "Cannot obtain WireGuard binary log URL for appGroupId \(appGroupId)")
        }
        return url
    }

    static var logTextFileURL: URL? {
        let url = ensureParentDirectoryExists(for: WireGuardLogPaths.textLogURL(appGroup: appGroupId))
        if url == nil {
            wg_log(.error, message: "Cannot obtain WireGuard text log URL for appGroupId \(appGroupId)")
        }
        return url
    }

    static var networkExtensionLastErrorFileURL: URL? {
        let url = WireGuardLogPaths.lastErrorURL(appGroup: appGroupId)
        if url == nil {
            wg_log(.error, message: "Cannot obtain WireGuard last-error URL for appGroupId \(appGroupId)")
        }
        return url
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
