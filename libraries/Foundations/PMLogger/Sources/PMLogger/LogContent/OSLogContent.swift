//
//  Created on 2022-06-06.
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
import OSLog

/// Reads all available logs from OSLog subsystem
public class OSLogContent: LogContent {
    private let scope: OSLogStore.Scope
    private let since: Date?
    private var filter: ((OSLogEntryLog) -> Bool)?

    public init(
        scope: OSLogStore.Scope = .currentProcessIdentifier,
        since: Date? = nil,
        filter: ((OSLogEntryLog) -> Bool)? = nil
    ) {
        self.scope = scope
        self.since = since
        self.filter = filter
    }

    private let dateFormatter = ISO8601DateFormatter()

    public func loadContent(callback: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            callback(getLogContents())
        }
    }

    public func loadContent() async -> String {
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return "" }
            return getLogContents()
        }.value
    }

    private func getLogContents() -> String {
        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let store = try OSLogStore(scope: scope)
            let position: OSLogPosition = if let since {
                store.position(date: since)
            } else {
                store.position(timeIntervalSinceLatestBoot: 1)
            }

            return try store.getEntries(at: position)
                .reduce(into: "==> \(Self.debugInfoString)\n") { partialResult, message in
                    guard let message = message as? OSLogEntryLog else { return }
                    partialResult += "\(message.process) | " +
                        "\(message.subsystem) | " +
                        "\(dateFormatter.string(from: message.date)) | " +
                        "\(message.level.stringValue.uppercased()) | " +
                        "\(message.composedMessage)\n"
                }
        } catch {
            return "Error collecting logs: \(error)"
        }
    }
}

extension OSLogEntryLog.Level {
    var stringValue: String {
        switch self {
        case .undefined:
            "Debug"
        case .debug:
            "Debug"
        case .info:
            "Info"
        case .notice:
            "Notice"
        case .error:
            "Error"
        case .fault:
            "Fatal"
        default:
            "Debug"
        }
    }
}
