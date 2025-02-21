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
import VPNAppCore
import AppIntents
import Domain

public struct DisconnectFromVPNIntent: AppIntent {
    public static var title: LocalizedStringResource = "Disconnect from VPN"

    public static var openAppWhenRun = false

    public init() { }

    public func perform() async throws -> some IntentResult {

        @Dependencies.Dependency(\.disconnectVPN) var disconnectVPN
        try? await disconnectVPN()
        return .result()
    }
}

public struct ConnectToVPNIntent: AppIntent {

    public static var title: LocalizedStringResource = "Connect to VPN"

    public static var openAppWhenRun = false

    @Parameter(title: "Recent Connection Index") var recentIndex: Int?

    public init() {
        recentIndex = nil
    }

    public init(recentIndex: Int) {
        self.recentIndex = recentIndex
    }

    public func perform() async throws -> some IntentResult {
        @Dependencies.Dependency(\.connectToVPN) var connectToVPN

        let connectionSpec = recentIndex.map { getRecentConnection($0) } ?? getDefaultConnection()

        if let connectionSpec = connectionSpec {
            try? await connectToVPN(connectionSpec)
        }
        return .result()
    }

    // MARK: - Private helpers:

    @Dependencies.Dependency(\.recentsStorage) private var recentsStorage
    @Dependencies.Dependency(\.defaultConnectionStorage) private var defaultConnectionStorage

    private func getRecentConnection(_ index: Int) -> ConnectionSpec? {

        @Dependencies.Dependency(\.connectionPresenter) var connectionPresenter

        return connectionPresenter.recentConnectionList(
            defaultConnectionPreference: .fastest,
            recents: recentsStorage.readFromStorage(),
            currentConnection: ConnectionSpec.defaultFastest
        ).elements[index].connection
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

public struct LoginIntent: AppIntent {
    public static var title: LocalizedStringResource = "Login"
    public static let openAppWhenRun = true

    public init() { }

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}
