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
import Connection
import Dependencies
import Domain
import Ergonomics
import ExtensionManager
import NetworkExtension
import Sharing
import UIKit
import WidgetKit

/// Sends the disconnect command and returns without waiting. Widget buttons and quick actions only.
public struct DisconnectCommandIntent: AppIntent {
    public static let title: LocalizedStringResource = "Disconnect from VPN"

    public static let isDiscoverable: Bool = false

    public static let openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        log.debug("Received DisconnectCommandIntent, perform method called", category: .appIntent)
        @Dependencies.Dependency(\.connectionCommandClient) var connectionCommandClient
        connectionCommandClient.send(.disconnect(.widget))
        return .result()
    }
}
