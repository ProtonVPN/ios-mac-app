//
//  Created on 10/07/2023.
//
//  Copyright (c) 2023 Proton AG
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
import XCTestDynamicOverlay

import VPNShared

public struct SettingsStorage: Sendable {
    public var getConnectionProtocol: @Sendable () async throws -> ConnectionProtocol
    public var setConnectionProtocol: @Sendable (ConnectionProtocol) async throws -> Void

    public var getNetShield: @Sendable () async throws -> NetShieldType
    public var setNetShield: @Sendable (NetShieldType) async throws -> Void

    public init(
        getConnectionProtocol: @Sendable @escaping () async throws -> ConnectionProtocol = unimplemented(placeholder: .smartProtocol),
        setConnectionProtocol: @Sendable @escaping (ConnectionProtocol) async throws -> Void = unimplemented(),
        getNetShield: @Sendable @escaping () async throws -> NetShieldType = unimplemented(placeholder: .off),
        setNetShield: @Sendable @escaping (NetShieldType) async throws -> Void = unimplemented()
    ) {
        self.getConnectionProtocol = getConnectionProtocol
        self.setConnectionProtocol = setConnectionProtocol
        self.getNetShield = getNetShield
        self.setNetShield = setNetShield
    }
}

public enum SettingsStorageKey: DependencyKey {
    public static let liveValue: SettingsStorage = .init()
}

extension DependencyValues {
    public var settingsStorage: SettingsStorage {
        get { self[SettingsStorageKey.self] }
        set { self[SettingsStorageKey.self] = newValue }
    }
}
