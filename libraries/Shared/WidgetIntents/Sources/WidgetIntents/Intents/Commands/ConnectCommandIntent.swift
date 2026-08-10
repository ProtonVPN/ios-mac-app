//
//  Created on 2026-02-10 by Pawel Jurczyk.
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

import AppIntents

/// Sends a connect command and returns without waiting. Widget buttons and quick actions only.
public struct ConnectCommandIntent: AppIntent {
    public static let title: LocalizedStringResource = "Connect to VPN with parameters"
    public static let openAppWhenRun = true
    public static let isDiscoverable: Bool = false

    /// Without @Parameter the widget archives the button with the default connection instead of the recent one.
    @Parameter(title: "Recent Index")
    var recentIndex: Int?

    public init() {}

    public init(recentIndex: Int) {
        self.recentIndex = recentIndex
    }

    public func perform() async throws -> some IntentResult {
        try await ConnectRequest(recentIndex: recentIndex).send()
        return .result()
    }
}
