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
import Foundation
import PMLogger

public struct ProTUNLogProvider {
    public let logContentForAppGroup: () -> LogArchiveContent
}

extension ProTUNLogProvider: DependencyKey {
    public static let liveValue: ProTUNLogProvider = .init(
        logContentForAppGroup: {
            ProTUNLogContent()
        }
    )
}

public extension DependencyValues {
    var protunLogProvider: ProTUNLogProvider {
        get { self[ProTUNLogProvider.self] }
        set { self[ProTUNLogProvider.self] = newValue }
    }
}

private struct ProTUNLogContent: LogArchiveContent {
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
