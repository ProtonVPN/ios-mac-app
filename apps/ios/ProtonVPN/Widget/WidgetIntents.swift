//
//  Created on 2025-01-13.
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

import Dependencies
import Ergonomics
import VPNAppCore
import AppIntents
import Domain
import UIKit
import Connection
import ComposableArchitecture
import WidgetKit

internal struct DisconnectFromVPNIntent: AppIntent {
    static var title: LocalizedStringResource = "Disconnect from VPN"

    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {

        @Dependencies.Dependency(\.disconnectVPN) var disconnectVPN
        try? await disconnectVPN()
        return .result()
    }
}

internal struct ConnectToVPNIntent: AppIntent {

    static var title: LocalizedStringResource = "Connect to VPN"

    static var openAppWhenRun = true

    @Parameter(title: "Recent Connection Index") var recentIndex: Int?

    init() {
        recentIndex = nil
    }

    init(recentIndex: Int) {
        self.recentIndex = recentIndex
    }

    func perform() async throws -> some IntentResult {
        @Dependencies.Dependency(\.connectToVPN) var connectToVPN
        @SharedReader(.connectionState) var connectionState: ConnectionState

        guard let spec = recentIndex.flatMap(getRecentConnection) ?? getDefaultConnection() else {
            return .result()
        }

        // Wait until the connection state is not .resolving
        _ = await $connectionState.publisher.values.first { state in
            if case .resolving = state { return false }
            return true
        }

        // Trigger connection
        try? await connectToVPN(spec, defaultConnectionStorage.getDefaultProtocol())

        // Wait until the state changes and matches the connection spec for either `connected` or `disconnecting` states
        let state = await $connectionState.publisher.values
            .first { state in
                switch state {
                case .connected(let intent, _, _, _):
                    return intent.spec == spec
                case .disconnecting(let intent, _):
                    return intent.spec == spec
                default:
                    return false
                }
            }

        // If connected, close the application.
        if case .connected = state {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            }
        }

        return .result()
    }

    // MARK: - Private helpers:

    @Dependencies.Dependency(\.recentsStorage) private var recentsStorage
    @Dependencies.Dependency(\.defaultConnectionStorage) private var defaultConnectionStorage

    private func getRecentConnection(_ index: Int) -> ConnectionSpec? {

        @Dependencies.Dependency(\.connectionInventory) var connectionInventory

        return connectionInventory.recentConnectionList(
            .fastest,
            recentsStorage.readFromStorage(),
            ConnectionSpec.defaultFastest
        ).elements[safe: index]?.connection
    }

    private func getDefaultConnection() -> ConnectionSpec? {
        let preference = try? defaultConnectionStorage.getPreference()
        switch preference ?? .fastest {
        case .fastest:
            return .defaultFastest
        case .mostRecent:
            let recents = recentsStorage.readFromStorage()
            return recents.elements.first?.connection ?? .defaultFastest
        case .recent(let spec):
            return spec
        }
    }
}

internal struct LoginIntent: AppIntent {
    static var title: LocalizedStringResource = "Login"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
