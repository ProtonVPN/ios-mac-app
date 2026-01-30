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

import Foundation

import CasePaths
import Dependencies

import CertificateAuthentication
import CoreConnection
import ExtensionManager
import LocalAgent
import Localization

import Domain
import Ergonomics
import Strings

@CasePathable
public enum ConnectionPreparationError: ProtonVPNError, Equatable {
    /// We found the feature in an unexpected non-disconnected state upon finishing preparation
    case featureNotReady
    case protocolSelectionError(ProtocolSelectionError)
    case wrapped(ConnectionError.WrappedError)

    public static let errorDomain = "ConnectionPreparationErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .featureNotReady:
            "PRNR" // PReparation Not Ready

        case .protocolSelectionError(.cancelled):
            "PRCC"

        case .protocolSelectionError(.portSelectionFailed):
            "PRPS"

        case .protocolSelectionError(.unexpectedProtocol(.ike)):
            "UXIK"

        case let .protocolSelectionError(.unexpectedProtocol(.openVpn(transport))):
            if case .tcp = transport { "UXOT" } else { "UXOU" }

        case .protocolSelectionError(.unexpectedProtocol(.wireGuard(.udp))):
            "UXWU"

        case .protocolSelectionError(.unexpectedProtocol(.wireGuard(.tcp))):
            "UXWT"

        case .protocolSelectionError(.unexpectedProtocol(.wireGuard(.tls))):
            "UXWS"

        case let .protocolSelectionError(.serverSelectionFailed(error)):
            error.charCode

        case .wrapped:
            "PRWE" // PReparation Wrapped Error
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .protocolSelectionError(.unexpectedProtocol(vpnProtocol)):
            includeCode(inside: Localizable.connectionErrorUnexpectedProtocol(vpnProtocol.localizedDescription))
        case .protocolSelectionError(.portSelectionFailed):
            includeCode(inside: Localizable.connectionErrorTimeout)
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
