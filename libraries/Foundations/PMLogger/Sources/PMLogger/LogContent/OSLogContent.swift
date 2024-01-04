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
@available(macOS 12.0, *)
public class OSLogContent: LogContent {
    private let scope: OSLogStore.Scope
    private let since: Date?
    private var filter: ((OSLogEntryLog) -> Bool) = {
        $0.process == "ProtonVPN"
    }
    
    public init(
        scope: OSLogStore.Scope = .currentProcessIdentifier,
        since: Date? = nil,
        filter: ((OSLogEntryLog) -> Bool)? = nil
    ) {
        self.scope = scope
        self.since = since

        if let filter {
            self.filter = filter
        }
    }
    
    private let dateFormatter = ISO8601DateFormatter()

    public func loadContent(callback: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let store = try OSLogStore(scope: self.scope)
                let position: OSLogPosition

                if let since = self.since {
                    position = store.position(date: since)
                } else {
                    position = store.position(timeIntervalSinceLatestBoot: 1)
                }

                let entries = try store.getEntries(at: position)
                    .compactMap { $0 as? OSLogEntryLog }
                    .filter(self.filter)
                    .map {
                        "\($0.process) | " +
                        "\($0.subsystem) | " +
                        "\(dateFormatter.string(from: $0.date)) | " +
                        "\($0.level.stringValue.uppercased()) | " +
                        "\($0.composedMessage)"
                    }
                let result = entries.joined(separator: "\n")
                callback(result)
            } catch {
                callback("Error collecting logs: \(error)")
            }
        }
    }
}

extension OSLogEntryLog.Level {
    var stringValue: String {
        switch self {
        case .undefined:
            return "Debug"
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .notice:
            return "Notice"
        case .error:
            return "Error"
        case .fault:
            return "Fatal"
        default:
            return "Debug"
        }
    }
}
