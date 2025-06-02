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

import Dependencies
import CasePaths

import Localization
import LocalAgent
import CoreConnection
import ExtensionManager
import CertificateAuthentication

import Domain
import Strings
import Ergonomics

@CasePathable
public enum ConnectionPreparationError: ProtonVPNError, Equatable {
    /// We found the feature in an unexpected non-disconnected state upon finishing preparation
    case featureNotReady
    case wrapped(ConnectionError.WrappedError)

    public static let errorDomain = "ConnectionPreparationErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .featureNotReady:
            return "PRNR" // PReparation Not Ready

        case .wrapped:
            return "PRWE" // PReparation Wrapped Error
        }
    }

    public var errorDescription: String? {
        includeCode(inside: Localizable.connectionErrorPreparation)
    }

    public var underlyingError: (any Error)? {
        if case .wrapped(let error) = self {
            return error.wrapped
        }
        return nil
    }
}
