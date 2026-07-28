//
//  Created on 2026-02-19 by Pawel Jurczyk.
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
import Connection
import Dependencies
import NetworkExtension
import Sharing
import Strings
import VPNAppCore
import WidgetKit

public struct ConnectVPNIntent: AppIntent {
    public static let title: LocalizedStringResource = "Connect to VPN"
    static let description = IntentDescription(
        "Connects to Proton VPN using your default connection settings.",
        resultValueName: "connected"
    )
    public static let openAppWhenRun = true
    public static let isDiscoverable = false

    private static let timeOut: Duration = .seconds(30)

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        @Dependencies.Dependency(\.connectionCommandClient) var connectionCommandClient
        connectionCommandClient.send(.connect(.defaultFastest, .smartProtocol, .widget))
        return .result(value: true)
    }
}
