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
import Dependencies
import Sharing
import UIKit

public struct DisconnectVPNIntent: AppIntent {
    public static let title: LocalizedStringResource = "Disconnect from VPN"
    static let description = IntentDescription("Disconnects your active VPN connection.")

    public static let openAppWhenRun = false

    private static let timeOut: Duration = .seconds(20)

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        @Dependencies.Dependency(\.disconnectVPN) var disconnectVPN
        try? await disconnectVPN(.widget)

        @SharedReader(.connectionState) var connectionState

        try await $connectionState.when(
            willMatch: { $0.is(\.disconnected) },
            every: .milliseconds(20),
            deadline: Self.timeOut,
            operation: { _ in }
        )

        return .result(value: connectionState.is(\.disconnected))
    }
}
