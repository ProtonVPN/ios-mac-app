//
//  Created on 09/06/2023.
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

import Foundation

import Dependencies
import Domain
import Strings
import VPNAppCore
import NetShield
import ComposableArchitecture

public enum ProtectionState: Equatable {
    case protected(netShield: NetShieldModel)
    case protectedSecureCore(netShield: NetShieldModel)
    case unprotected
    case protecting(country: String, ip: String)

    func copy(withNetShield netShield: NetShieldModel) -> ProtectionState {
        switch self {
        case .protected:
            return .protected(netShield: netShield)
        case .protectedSecureCore:
            return .protectedSecureCore(netShield: netShield)
        case .unprotected:
            return self
        case .protecting:
            return self
        }
    }
}

extension VPNConnectionStatus {
    func protectionState(country: String, ip: String) async -> ProtectionState {
        @Dependency(\.netShieldStatsProvider) var provider
        switch self {
        case .disconnected:
            return .unprotected
        case .connected(let spec, _):
            if case .secureCore = spec.location {
                return .protectedSecureCore(netShield: await provider.getStats())
            }
            return .protected(netShield: await provider.getStats())
        case .connecting, .loadingConnectionInfo:
            return .protecting(country: country, ip: ip)
        case .disconnecting:
            return .unprotected
        }
    }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<ProtectionState>> {
    static var protectionState: Self {
        PersistenceKeyDefault(.inMemory("protectionState"), .unprotected)
    }
}
