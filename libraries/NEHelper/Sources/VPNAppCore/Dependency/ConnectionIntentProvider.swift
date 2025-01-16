//
//  Created on 09/01/2025.
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

public struct DisconnectFromVPNIntent: AppIntent {
    public static var title: LocalizedStringResource = "Disconnect from VPN"

    public init() { }

    public func perform() async throws -> some IntentResult {
        return .result()
    }
import DependenciesMacros
import Domain

@DependencyClient
public struct ConnectionIntentStorage: TestDependencyKey, Sendable {
    public internal(set) var getConnectionIntent: @Sendable () throws -> ServerConnectionIntent
    public internal(set) var set: @Sendable (_ connectionIntent: ServerConnectionIntent) throws -> Void

    public static let testValue = ConnectionIntentStorage()
}

public struct ConnectToVPNIntent: AppIntent {
    public static var title: LocalizedStringResource = "Connect to VPN"

    public init() { }

extension DependencyValues {
    public var connectionIntentStorage: ConnectionIntentStorage {
        get { self[ConnectionIntentStorage.self] }
        set { self[ConnectionIntentStorage.self] = newValue }
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
