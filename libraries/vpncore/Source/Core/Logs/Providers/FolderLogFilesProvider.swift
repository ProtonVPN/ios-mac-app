//
//  Created on 2022-02-15.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

/// Provides all the log files contained in the same folder as `appLogFilename`
public class FolderLogFilesProvider: LogFilesProvider {

    private let appLogFilename: String
    private let fileManager: FileManager = FileManager.default

    public init(appLogFilename: String) {
        self.appLogFilename = appLogFilename
    }

    public var logFiles: [(String, URL?)] {
        guard let fileUrl = URL(string: appLogFilename) else {
            log.error("Can't read log files. Wrong url given", category: .app, metadata: ["appLogFilename": "\(appLogFilename)"])
            return []
        }
        let logsDirectory: URL = fileUrl.deletingLastPathComponent()

        guard let allFiles = try? fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter({ $0.pathComponents.last?.hasMatches(for: ".+.log") ?? false }) else {
            log.error("Can't read log files", category: .app, metadata: ["folder": "\(logsDirectory)"])
            return []
        }

        return allFiles.map { url in (url.lastPathComponent, url) }
    }

}
