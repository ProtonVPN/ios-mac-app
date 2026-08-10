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
import Ergonomics
import Sharing
import UIKit

public struct DisconnectVPNIntent: AppIntent {
    public static let title: LocalizedStringResource = "Disconnect from VPN"
    static let description = IntentDescription(
        "Disconnects your active VPN connection.",
        resultValueName: "disconnected"
    )

    public static let openAppWhenRun = true
    public static let isDiscoverable = true

    private static let timeOut: Duration = .seconds(30)

    @SharedReader(.connectionState) var connectionState

    public init() {}

    func finishResolving() async throws {
        // Wait until the connection state is not .resolving
        try await $connectionState.when(
            willMatch: { !$0.is(\.resolving) },
            every: .milliseconds(200),
            deadline: Self.timeOut,
            operation: { _ in }
        )
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        do {
            try await finishResolving()
        } catch {
            log.error("The connectionState hasn’t changed from `resolving` in \(Self.timeOut) seconds. Skipping the widget disconnect intent.", category: .connectionDisconnect)
            return .result(value: false)
        }

        @Dependencies.Dependency(\.connectionCommandClient) var connectionCommandClient
        connectionCommandClient.send(.disconnect(.widget))

        log.debug("Waiting for connection state to update to <disconnected>", category: .connectionDisconnect)

        do {
            try await $connectionState.when(
                willMatch: { $0.is(\.disconnected) },
                every: .milliseconds(200),
                deadline: Self.timeOut,
                operation: { _ in }
            )
        } catch {
            log.error("Timed out waiting for disconnected state after widget action", category: .connectionDisconnect, metadata: ["error": "\(error)"])
        }
        let value = connectionState.is(\.disconnected)
        log.debug("Finished waiting for connection state to update to <disconnected>, actual state: \(connectionState), will return value: \(value)", category: .connectionDisconnect)
        return .result(value: value)
    }
}
