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

import Dependencies
import ExtensionIPC
import Foundation
import PMLogger

#if os(iOS) || os(tvOS)
    public struct WireguardIOSLogProvider {
        public let logContentForAppGroup: (_ appGroup: String) -> LogContent
    }

    extension WireguardIOSLogProvider: DependencyKey {
        public static let liveValue: WireguardIOSLogProvider = .init(
            logContentForAppGroup: { appGroup in
                WireguardIOSLogContent(appGroup: appGroup)
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
        // Name of the log file from WireGuard NE.
        private static let wireguardLogFile = "WireGuard.log"
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
            // We don't care if flush succeeded or not. In case NE is not up and runnning it means latest logs were already saved to file.
            _ = try? await messageSender.send(WireguardProviderRequest.flushLogsToFile)

            let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) ?? FileManager.default.temporaryDirectory
            let contents = try? String(contentsOf: folder.appendingPathComponent(Self.wireguardLogFile))

            return contents ?? ""
        }
    }
#endif
