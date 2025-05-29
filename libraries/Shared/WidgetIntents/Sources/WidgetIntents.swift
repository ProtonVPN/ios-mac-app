//
//  Created on 07/05/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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
import ComposableArchitecture
import Connection
import ConnectionInventory
import Domain
import Logging
import UIKit
import VPNAppCore

let log: Logging.Logger = .init(label: "ProtonVPN.WidgetIntents.logger")

public struct DisconnectFromVPNIntent: AppIntent {
    public static var title: LocalizedStringResource = "Disconnect from VPN"

    public static var openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        @Dependencies.Dependency(\.disconnectVPN) var disconnectVPN
        try? await disconnectVPN(.widget)
        return .result()
    }
}

public struct ConnectToVPNIntent: AppIntent {
    public static var title: LocalizedStringResource = "Connect to VPN"
    public static var openAppWhenRun = true

    private static let timeOut = 20 // 20 Seconds

    @Parameter(title: "Recent Connection Index")
    var recentIndex: Int?

    public init() {
        self.recentIndex = nil
    }

    public init(recentIndex: Int) {
        self.recentIndex = recentIndex
    }

    public func perform() async throws -> some IntentResult {
        @Dependencies.Dependency(\.connectToVPN) var connectToVPN
        @SharedReader(.connectionState) var connectionState: ConnectionState

        guard let spec = recentIndex.flatMap(getRecentConnection) ?? getDefaultConnection() else {
            return .result()
        }

        // Wait until the connection state is not .resolving
        guard let _ = try? await $connectionState.when(willMatch: {
            if case .resolving = $0 { return false }
            return true
        }, every: .milliseconds(20), deadline: .seconds(Self.timeOut), operation: { _ in
            // no-op
        }) else {
            log.error("The connectionState hasn’t been changed from `resolving` in \(Self.timeOut) seconds. Skipping the widget connection intent.")
            return .result()
        }

        // Trigger connection
        do {
            try await connectToVPN(spec, defaultConnectionStorage.getDefaultProtocol(), .widget)
        } catch {
            log.error("Failed to connect to VPN from widget with error: \(error)")
        }

        // Wait until the connection state either goes into .connected or .disconnecting.
        try? await $connectionState.when(willMatch: { state in
            switch state {
            case let .connected(intent, _, _, _):
                intent.spec == spec
            case let .disconnecting(intent, _):
                intent.spec == spec
            default:
                false
            }
        }, every: .milliseconds(20), deadline: .seconds(Self.timeOut), operation: { state in
            if case .connected = state {
                // VPN connection established, now suspending the app.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
            }
        })

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
        case let .recent(spec):
            return spec
        }
    }
}

public struct LoginIntent: AppIntent {
    public static var title: LocalizedStringResource = "Login"
    public static let openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public struct WidgetIntentsPackage: AppIntentsPackage {}
