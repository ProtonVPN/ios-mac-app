//
//  Created on 2022-06-02.
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

/// Class for savinglog to temporary files, so they can be uploaded with a bug report or used in any other way.
/// Object should be retained as long as you need the files. WHen object is deallocated, temporary files are deleted.
class LogFilesTemporaryStorage {
    private let logContentProvider: LogContentProvider
    private let logSources: [LogSource]

    private let fileManager = FileManager.default
    private var savedFiles: [URL] = []

    init(logContentProvider: LogContentProvider, logSources: [LogSource]) {
        self.logContentProvider = logContentProvider
        self.logSources = logSources
    }

    deinit {
        log.error("LogFilesTemporaryStorage.deinit")
    }

    /// Writes logs to temporary files that can be uploaded to API and saves that list internally to clean up after object is deallocated
    func prepareLogs(responseHandler: @escaping ([URL]) -> Void) {
        assert(savedFiles.isEmpty, "Do not call prepareLogs on a non-clean state")
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated) // For writing to array without race conditions

        logSources.forEach { source in
            dispatchGroup.enter()

            let contentProvider = self.logContentProvider.getLogData(for: source)
            contentProvider.loadContent { content in
                guard !content.isEmpty else {
                    dispatchGroup.leave()
                    return
                }

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(source.title).log")
                do {
                    if self.fileManager.fileExists(atPath: tempFile.path) {
                        try self.fileManager.removeItem(at: tempFile)
                    }

                    try content.write(to: tempFile, atomically: true, encoding: .utf8)

                    queue.async {
                        self.savedFiles.append(tempFile)
                        dispatchGroup.leave()
                    }

                } catch {
                    log.error("Can't save temporary log file", category: .app, event: .error, metadata: ["error": "\(error)", "source": "\(source.title)", "file": "\(tempFile)"])
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            responseHandler(self.savedFiles)
        }
    }

    /// Deletes temp log files after upload is done
    public func deleteTempLogs() {
        savedFiles.forEach { file in
            try? self.fileManager.removeItem(at: file)
        }
        savedFiles.removeAll()
    }

}
