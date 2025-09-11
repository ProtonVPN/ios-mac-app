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

    /// An error occurred while performing certificate authentication.
    ///
    /// This could be a mismatch, a failure to fetch, an IPC error, or some other unexpected issue.
    case certAuth(CertificateAuthenticationError)
    /// An error occurred while starting the tunnel - either an operating system issue, or the server is unknown.
    case tunnel(TunnelConnectionError)
    /// The LocalAgent on the server has sent an error to us, or we encountered an error trying to connect to it.
    case agent(LocalAgentConnectionError)
    /// An error occurred while trying to prepare to connect to the server.
    case preparation(ConnectionPreparationError)
    /// Original connection intent is missing, and we cannot provide accurate connection details
    case intentMissing
    /// Connection was attempted to a server that is no longer in the server list.
    case serverMissing
    /// The connection timed out.
    case timeout(CoreConnectionFeature.ConnectionStage)
}

extension ConnectionError: ProtonVPNError {
    public static let errorDomain = "ConnectionErrorDomain"

    public var errorDescription: String? {
        switch self {
        case let .certAuth(certAuthError):
            certAuthError.errorDescription
        case let .tunnel(tunnelError):
            tunnelError.errorDescription
        case let .agent(agentError):
            agentError.errorDescription
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
        case let .certAuth(certAuthError):
            certAuthError.charCode
        case .tunnel:
            "TUNN"
        case .agent:
            "AGNT"
        case let .preparation(preparationError):
            preparationError.charCode
        case .intentMissing:
            "ITNT"
        case .serverMissing:
            "SVRM"
        case let .timeout(stage):
            switch stage {
            case .tunnelStartingAndConnecting:
                "TOTS"
            case .refreshingCertificate:
                "TORC"
            case .connectingToLocalAgentServer:
                "TOLA"
            }
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .tunnel(tunnelError):
            tunnelError
        case let .certAuth(certAuthError):
            certAuthError
        case let .agent(agentError):
            agentError
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
        case .certAuth:
            break
        case .tunnel:
            break
        case let .agent(agentError):
            return agentError.alert
        case .preparation(.featureNotReady):
            break
        case .preparation(.protocolSelectionError(.cancelled)):
            break
        case .preparation(.protocolSelectionError(.portSelectionFailed)):
            break
        case .preparation(.protocolSelectionError(.unexpectedProtocol)):
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

extension LocalAgentConnectionError: AlertConvertibleError {
    public var alert: Alert {
        switch self {
        case .failedToEstablishConnection:
            break
        case let .agentError(agentError):
            return agentError.alert
        case .serverCertificateError:
            break
        }

        guard let errorDescription else {
            return .connectionFailedAlert
        }

        return .init(title: Localizable.connectionErrorTitle, message: errorDescription)
    }
}

extension LocalAgentError: AlertConvertibleError {
    public var alert: Alert {
        switch self {
        case .restrictedServer,
             .certificateExpired,
             .certificateRevoked:
            break
        case .maxSessionsUnknown,
             .maxSessionsFree,
             .maxSessionsBasic,
             .maxSessionsPlus,
             .maxSessionsVisionary,
             .maxSessionsPro:
            let message = Localizable.maximumDeviceReachedDescription
            let title = Localizable.maximumDeviceTitle
            return .init(title: title, message: message)
        case .keyUsedMultipleTimes:
            break
        case .serverError:
            let title = Localizable.localAgentServerErrorTitle
            let message = Localizable.localAgentServerErrorMessage
            return .init(title: title, message: message)
        case .policyViolationLowPlan:
            let title = Localizable.localAgentPolicyViolationErrorTitle
            let message = Localizable.localAgentPolicyViolationErrorMessage
            return .init(title: title, message: message)
        case .policyViolationDelinquent:
            let title = Localizable.delinquentUserTitle
            let message = Localizable.delinquentUserDescription
            return .init(title: title, message: message)
        case .userTorrentNotAllowed:
            let title = Localizable.p2pDetectedPopupTitle
            let message = Localizable.p2pDetectedPopupBody
            return .init(title: title, message: message)
        case .userBadBehavior:
            break // Possible disconnection error, but no specific message to the user
        case .guestSession:
            break // Possible disconnection error, but no specific message to the user
        case .badCertificateSignature,
             .certificateNotProvided,
             .serverSessionDoesNotMatch,
             .systemError,
             .unknown:
            break
        case .authenticationError:
            // TODO: `Alert` conforming 2FA alert here
            break
        }
        return .connectionFailedAlert
    }
}

extension ConnectionError.WrappedError: AlertConvertibleError {
    public var alert: Alert {
        .connectionFailedAlert
    }
}
