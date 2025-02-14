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

    @Parameter(title: "Country") var country: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Connect to \(\.$country)") {
            \.$country
        }
    }

    public init() {
        self.country = "US"
    }

    public init(country: String) {
        self.country = country
    }

    public func perform() async throws -> some IntentResult {
        @Dependencies.Dependency(\.connectToVPN) var connectToVPN
        try? await connectToVPN(.init(location: .region(code: country), features: []))
        return .result()
    }
}
