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
@available(iOS 15, macOS 12, *)
public class OSLogContent: LogContent {
    
    public init(){
    }
    
    private let dateFormatter = ISO8601DateFormatter()

    public func loadContent(callback: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(timeIntervalSinceLatestBoot: 1)
                let entries = try store.getEntries(at: position)
                    .compactMap { $0 as? OSLogEntryLog }
                    .filter { $0.subsystem == "PROTON-APP" }
                    .map { "\(dateFormatter.string(from: $0.date)) | \($0.level.stringValue.uppercased()) | \($0.composedMessage)" }
                let result = entries.joined(separator: "\n")
                callback(result)

            } catch {
                callback("")
            }
        }
    }
}

@available(iOS 15, macOS 12, *)
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
