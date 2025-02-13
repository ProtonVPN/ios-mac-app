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
import AppIntents

/// These intents are never actually used. They are only here in order to be able to invoke them from this package.
/// The real implementation lives in the iOS app target.

public struct DisconnectFromVPN: AppIntent {
    public static var title: LocalizedStringResource = "Disconnect from VPN"

    public init() { }

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

public struct ConnectToVPN: AppIntent {
    public static var title: LocalizedStringResource = "Connect to VPN"

    public init() { }

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}
