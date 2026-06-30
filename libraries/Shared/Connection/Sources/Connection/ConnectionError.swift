//
//  Created on 19.02.2025.
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
public enum ConnectionError: Error, Equatable, Sendable {
    public struct WrappedError: Error, Equatable {
        let wrapped: any Error

        public init(wrapped: any Error) {
            self.wrapped = wrapped
        }

        public static func == (lhs: WrappedError, rhs: WrappedError) -> Bool {
            String(reflecting: lhs.wrapped) == String(reflecting: rhs.wrapped)
        }
    }

    /// An error occurred while starting the tunnel - either an operating system issue, or the server is unknown.
    case tunnel(TunnelConnectionError)
    /// An error occurred while trying to prepare to connect to the server.
    case preparation(ConnectionPreparationError)
    /// Original connection intent is missing, and we cannot provide accurate connection details
    case intentMissing
    /// Connection was attempted to a server that is no longer in the server list.
    case serverMissing
    /// The connection timed out.
    case timeout(ConnectionStage)
}

extension ConnectionError: ProtonVPNError {
    public static let errorDomain = "ConnectionErrorDomain"

    public var errorDescription: String? {
        switch self {
        case let .tunnel(tunnelError):
            tunnelError.errorDescription
        case let .preparation(preparationError):
            preparationError.errorDescription
        case .intentMissing:
            includeCode(inside: Localizable.connectionErrorIntentMissing)
        case .serverMissing:
            includeCode(inside: Localizable.connectionErrorServerMissing)
        case .timeout:
            includeCode(inside: Localizable.connectionErrorTimeout)
        }
    }

    public var charCode: FourCharCode {
        switch self {
        case .tunnel:
            "TUNN"
        case let .preparation(preparationError):
            preparationError.charCode
        case .intentMissing:
            "ITNT"
        case .serverMissing:
            "SVRM"
        case let .timeout(stage):
            switch stage {
            case .tunnel(.configuration):
                "TOTI"
            case .tunnel(.start):
                "TOTS"
            case .tunnel(.connection):
                "TOTC"
            case .connectingToLocalAgentServer:
                "TOLA"
            }
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .tunnel(tunnelError):
            tunnelError
        case let .preparation(preparationError):
            preparationError.underlyingError
        default:
            nil
        }
    }
}

public extension Alert {
    static let connectionFailedAlert = Self(message: Localizable.connectionFailed)
}

extension ConnectionError: AlertConvertibleError {
    public var alert: Alert {
        switch self {
        case .tunnel:
            break
        case .preparation(.featureNotReady):
            break
        case .preparation(.networkUnreachable):
            return .init(title: Localizable.networkUnreachable, message: Localizable.notConnectedToTheInternet)
        case .preparation(.intentResolution(.cancelled)):
            break
        case .preparation(.intentResolution(.unexpectedProtocol)):
            break
        case .preparation(.intentResolution(.serverSelectionFailed)):
            break
        case let .preparation(.wrapped(wrappedError)):
            return wrappedError.alert
        case .serverMissing:
            break
        case .intentMissing:
            break
        case .timeout:
            break
        }

        guard let errorDescription else {
            return .connectionFailedAlert
        }

        return .init(title: Localizable.connectionErrorTitle, message: errorDescription)
    }
}

extension ConnectionError.WrappedError: AlertConvertibleError {
    public var alert: Alert {
        .connectionFailedAlert
    }
}
