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

/// Manages the packet capture file, ensuring that it is consistent with the capture state.
@DependencyClient
public struct PCAPFileManager: Sendable {
    public struct CaptureFile: Equatable, Sendable {
        public let url: URL
        public let size: Int
        public let created: Date

        public init(url: URL, size: Int, created: Date) {
            self.url = url
            self.size = size
            self.created = created
        }
    }

    /// Creates an capture file and clears out whatever an earlier capture left behind.
    public var createCaptureFile: @Sendable () throws -> URL
    /// The capture file as it currently stands, or nil when none exists.
    public var captureFile: @Sendable () -> CaptureFile?
    public var removeCaptureFiles: @Sendable () throws -> Void
}

extension PCAPFileManager: DependencyKey {
    static let captureFileName = "capture.pcap"
    static let pcapDirectoryPath = "/PcapFiles"

    public static var liveValue: PCAPFileManager {
        PCAPFileManager(
            createCaptureFile: {
                let fileManager = FileManager.default
                let directory = try pcapDirectory()
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                try removeDirectoryContents()

                let fileURL = directory.appendingPathComponent(captureFileName)
                fileManager.createFile(atPath: fileURL.path(percentEncoded: false), contents: Data())
                return fileURL
            },
            captureFile: {
                do {
                    let fileURL = try pcapDirectory().appendingPathComponent(captureFileName)
                    let attributes = try FileManager.default.attributesOfItem(
                        atPath: fileURL.path(percentEncoded: false)
                    )
                    return CaptureFile(
                        url: fileURL,
                        size: attributes[.size] as? Int ?? 0,
                        created: attributes[.creationDate] as? Date ?? .distantPast
                    )
                } catch let error as CocoaError where [.fileNoSuchFile, .fileReadNoSuchFile].contains(error.code) {
                    // No file means no capture, the ordinary case for anyone not using the feature.
                    return nil
                } catch {
                    log.error("Failed to read the capture file", category: .app, metadata: ["error": "\(error)"])
                    return nil
                }
            },
            removeCaptureFiles: {
                try removeDirectoryContents()
            }
        )
    }

    private static func pcapDirectory() throws -> URL {
        try FileManager.default
            .mainContainerURL
            .appendingPathComponent(pcapDirectoryPath)
    }

    private static func removeDirectoryContents() throws {
        let directory = try pcapDirectory()
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return
        }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: file)
        }
    }
}

public extension DependencyValues {
    var pcapFileManager: PCAPFileManager {
        get { self[PCAPFileManager.self] }
        set { self[PCAPFileManager.self] = newValue }
    }
}
