//
//  Created on 30/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import let CoreConnection.log
import Dependencies
import ExtensionIPC
import Foundation
import PMLogger

#if os(iOS) || os(tvOS)
    public struct WireguardIOSLogProvider {
        public var logContentForAppGroup: (_ appGroup: String) -> LogContent
        public var clearLogsForAppGroup: (_ appGroup: String) -> Void
    }

    extension WireguardIOSLogProvider: DependencyKey {
        public static let liveValue: WireguardIOSLogProvider = .init(
            logContentForAppGroup: { appGroup in
                WireguardIOSLogContent(appGroup: appGroup)
            },
            clearLogsForAppGroup: { appGroup in
                let logURLs = [
                    WireGuardLogPaths.binaryLogURL(appGroup: appGroup),
                    WireGuardLogPaths.textLogURL(appGroup: appGroup),
                    WireGuardLogPaths.lastErrorURL(appGroup: appGroup),
                ]

                for case let fileURL? in logURLs where FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                    } catch {
                        log.error("Failed to remove WireGuard log file at \(fileURL.path): \(error)")
                    }
                }
            }
        )
    }

    public extension DependencyValues {
        var wireguardIOSLogProvider: WireguardIOSLogProvider {
            get { self[WireguardIOSLogProvider.self] }
            set { self[WireguardIOSLogProvider.self] = newValue }
        }
    }

    private struct WireguardIOSLogContent: LogContent {
        private let appGroup: String

        fileprivate init(appGroup: String) {
            self.appGroup = appGroup
        }

        func loadContent(callback: @escaping (String) -> Void) {
            Task(priority: .userInitiated) {
                let content = await getLogContents()
                callback(content)
            }
        }

        func loadContent() async -> String {
            await getLogContents()
        }

        private func getLogContents() async -> String {
            @Dependency(\.tunnelMessageSender) var messageSender
            _ = try? await messageSender.send(WireguardProviderRequest.flushLogsToFile)

            guard let url = WireGuardLogPaths.textLogURL(appGroup: appGroup) else {
                log.warning("Couldn't get URL for WireGuard log file with appGroup: \(appGroup)")
                return ""
            }
            guard let contents = try? String(contentsOf: url), !contents.isEmpty else {
                log.info("No content in WireGuard log file with url: \(url)")
                return ""
            }
            return contents
        }
    }
#endif
