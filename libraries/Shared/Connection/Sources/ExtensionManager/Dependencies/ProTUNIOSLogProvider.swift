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

#if DEBUG && os(iOS)
    import let CoreConnection.log
    import Dependencies
    import ExtensionIPC
    import Foundation
    import PMLogger

    public struct ProTUNIOSLogProvider {
        public let logContentForAppGroup: (_ appGroup: String) -> LogArchiveContent
    }

    extension ProTUNIOSLogProvider: DependencyKey {
        public static let liveValue: ProTUNIOSLogProvider = .init(
            logContentForAppGroup: { appGroup in
                ProTUNIOSLogContent(appGroup: appGroup)
            }
        )
    }

    public extension DependencyValues {
        var protunIOSLogProvider: ProTUNIOSLogProvider {
            get { self[ProTUNIOSLogProvider.self] }
            set { self[ProTUNIOSLogProvider.self] = newValue }
        }
    }

    private struct ProTUNIOSLogContent: LogArchiveContent {
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

            guard let response = try? await messageSender.sendProTUN(.init(payload: .flushLogsToFile)) else {
                return ""
            }
            guard case let .logs(.success(url)) = response.payload else {
                return ""
            }
            guard let contents = try? String(contentsOf: url), !contents.isEmpty else {
                log.error("No content in ProTUN log file with url: \(url)")
                return ""
            }

            return contents
        }

        func loadArchive() async -> URL? {
            @Dependency(\.tunnelMessageSender) var messageSender

            guard let response = try? await messageSender.sendProTUN(.init(payload: .retrieveLogsArchive)) else {
                return nil
            }
            guard case let .logs(.success(url)) = response.payload else {
                return nil
            }

            return url
        }
    }
#endif
