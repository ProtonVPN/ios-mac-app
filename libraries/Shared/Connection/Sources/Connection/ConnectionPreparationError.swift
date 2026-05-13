//
//  Created on 02/06/2025 by Chris Janusiewicz.
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

import CasePaths
import CoreConnection
import Dependencies
import Domain
import Ergonomics
import ExtensionManager
import Foundation
import Localization
import Strings

@CasePathable
public enum ConnectionPreparationError: ProtonVPNError, Equatable {
    /// We found the feature in an unexpected non-disconnected state upon finishing preparation
    case featureNotReady
    case networkUnreachable
    case intentResolution(IntentResolutionError)
    case wrapped(ConnectionError.WrappedError)

    public static let errorDomain = "ConnectionPreparationErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .featureNotReady:
            "PRNR" // PReparation Not Ready
        case .networkUnreachable:
            "NWUN" // NetWork UNreachable

        case .intentResolution(.cancelled):
            "PRCC"

        case .intentResolution(.unexpectedProtocol(.ike)):
            "UXIK"

        case .intentResolution(.unexpectedProtocol(.wireGuard(.udp))):
            "UXWU"

        case .intentResolution(.unexpectedProtocol(.wireGuard(.tcp))):
            "UXWT"

        case .intentResolution(.unexpectedProtocol(.wireGuard(.tls))):
            "UXWS"

        case let .intentResolution(.serverSelectionFailed(error)):
            error.charCode

        case .wrapped:
            "PRWE" // PReparation Wrapped Error
        }
    }

    public var errorDescription: String? {
        switch self {
        case .networkUnreachable:
            includeCode(inside: Localizable.networkUnreachable)
        case let .intentResolution(.unexpectedProtocol(vpnProtocol)):
            includeCode(inside: Localizable.connectionErrorUnexpectedProtocol(vpnProtocol.localizedDescription))
        default:
            includeCode(inside: Localizable.connectionErrorPreparation)
        }
    }

    public var underlyingError: (any Error)? {
        if case let .wrapped(error) = self {
            return error.wrapped
        }
        return nil
    }
}
