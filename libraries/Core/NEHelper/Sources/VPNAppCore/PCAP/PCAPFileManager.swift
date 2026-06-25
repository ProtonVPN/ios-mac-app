//
//  Created on 2026-06-24 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct PCAPFileManager: Sendable {
    static let pcapPathExtension: String = "pcap"
    static let pcapDirectoryPath: String = "/PcapFiles"

    public var newFileURL: (_ startDate: Date) throws -> URL
    public var cleanUpAllPcapFiles: () throws -> Void
    public var retrieveLastPcapFileURL: () -> URL?
}

extension PCAPFileManager: DependencyKey {
    public static var liveValue: PCAPFileManager {
        let fileManager = FileManager.default

        func pcapDirectory() throws -> URL {
            try fileManager
                .mainContainerURL
                .appendingPathComponent(pcapDirectoryPath)
        }

        return PCAPFileManager(
            newFileURL: { date in
                let formatter = DateFormatter()
                formatter.dateFormat = "ddMMyyyyHHmmss"
                formatter.locale = Locale(identifier: "en_US_POSIX")

                let timestamp = formatter.string(from: date)

                return try pcapDirectory()
                    .appendingPathComponent(timestamp)
                    .appendingPathExtension(Self.pcapPathExtension)
            },
            cleanUpAllPcapFiles: {
                try fileManager.subpaths(atPath: pcapDirectory().absoluteString)?.forEach { path in
                    try fileManager.removeItem(atPath: path)
                }
            },
            retrieveLastPcapFileURL: {
                do {
                    let directory = try pcapDirectory()
                    let files = try fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.creationDateKey],
                        options: [.skipsHiddenFiles]
                    )
                    return files
                        .filter { $0.pathExtension == Self.pcapPathExtension }
                        .sortedByCreationDate
                        .first
                } catch {
                    log.error("Failed to retrieve last PCAP file URL", category: .app, metadata: ["error": "\(error)"])
                    return nil
                }
            }
        )
    }
}

public extension DependencyValues {
    var pcapFileManager: PCAPFileManager {
        get { self[PCAPFileManager.self] }
        set { self[PCAPFileManager.self] = newValue }
    }
}

private extension Collection<URL> {
    var sortedByCreationDate: [URL] {
        sorted { a, b in
            let d1 = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let d2 = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return d1 > d2
        }
    }
}
