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

import ComposableArchitecture
import Connection
import Dependencies
import Domain
import Foundation
import VPNAppCore

public enum ProtectionState: Equatable, Sendable {
    case resolving // Transitionary state. Shown at app start while we figure out what state the tunnel is in.
    case protected
    case protectedSecureCore
    case unprotected
    case protecting(country: String?, ip: String?)
    case authenticationRequired
    case killSwitchActive
}

extension ConnectionState {
    func protectionState(country: String?, ip: String?) -> ProtectionState {
        switch self {
        case .disconnected:
            return .unprotected
        case let .connected(tunnelConfig, _):
            if case .secureCore = tunnelConfig.connectionSpec.location {
                return .protectedSecureCore
            }
            return .protected
        case .connecting:
            return .protecting(country: country, ip: ip)
        case .authenticationRequired:
            return .authenticationRequired
        case .resolving:
            return .resolving
        case .disconnecting:
            return .unprotected
        case .killSwitchActive:
            return .killSwitchActive
        }
    }
}

public extension SharedKey where Self == InMemoryKey<ProtectionState>.Default {
    static var protectionState: Self {
        Self[.inMemory("protectionState"), default: .resolving]
    }
}
