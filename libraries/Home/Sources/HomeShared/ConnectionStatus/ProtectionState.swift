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
    case resolving // Transitionary state. Shown at app start while we figure out what state the tunnel is in.
    case protected(netShield: NetShieldModel?)
    case protectedSecureCore(netShield: NetShieldModel?)
    case unprotected
    case protecting(country: String, ip: String)

    func copy(withNetShield netShield: NetShieldModel) -> ProtectionState {
        switch self {
        case .resolving:
            return self
        case .protected:
            return .protected(netShield: netShield.copy(enabled: true))
        case .protectedSecureCore:
            return .protectedSecureCore(netShield: netShield.copy(enabled: true))
        case .unprotected:
            return self
        case .protecting:
            return self
        }
    }

    public var netShieldModel: NetShieldModel? {
        switch self {
        case .protected(let netShield), .protectedSecureCore(let netShield):
            return netShield
        case .unprotected, .protecting, .resolving:
            return nil
        }
    }
}

extension VPNConnectionStatus {
    func protectionState(country: String, ip: String, netShieldModel: NetShieldModel? = nil) -> ProtectionState {
        switch self {
        case .disconnected:
            return .unprotected
        case .connected(let spec, _):
            if case .secureCore = spec.location {
                return .protectedSecureCore(netShield: netShieldModel?.copy(enabled: true))
            }
            return .protected(netShield: netShieldModel?.copy(enabled: true))
        case .connecting:
            return .protecting(country: country, ip: ip)
        case .resolving:
            return .resolving
        case .disconnecting:
            return .unprotected
        }
    }
}

public extension SharedKey where Self == InMemoryKey<ProtectionState>.Default {
    static var protectionState: Self {
        Self[.inMemory("protectionState"), default: .resolving]
    }
}
