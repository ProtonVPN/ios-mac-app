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
    /// Asked to connect with a protocol that is no longer supported, such as OpenVPN.
    ///
    /// This error (should be) quite rare and will only happen when the user has stale configuration data from a
    /// previous version of the app.
    case unexpectedProtocol(VpnProtocol)
    /// An error occurred while performing certificate authentication.
    ///
    /// This could be a mismatch, a failure to fetch, an IPC error, or some other unexpected issue.
    case certAuth(CertificateAuthenticationError)
    /// An error occurred while starting the tunnel - either an operating system issue, or the server is unknown.
    case tunnel(TunnelConnectionError)
    /// The LocalAgent on the server has sent an error to us, or we encountered an error trying to connect to it.
    case agent(LocalAgentConnectionError)
    /// An error occurred while trying to prepare to connect to the server.
    case preparation(WrappedError)
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
        case .unexpectedProtocol(let vpnProtocol):
            return Localizable.connectionErrorUnexpectedProtocol(vpnProtocol.localizedDescription, errorCodeString)
        case .certAuth(let certAuthError):
            return certAuthError.errorDescription
        case .tunnel(let tunnelError):
            return tunnelError.errorDescription
        case .agent(let agentError):
            return agentError.errorDescription
        case .preparation(let wrapped):
            if let protonVpnError = wrapped.wrapped as? ProtonVPNError {
                return protonVpnError.errorDescription
            } else {
                let error = wrapped.wrapped as NSError
                return Localizable.connectionErrorPreparation("\(error.domain) 0x\(String(error.code, radix: 16))")
            }
        case .intentMissing:
            return includeCode(inside: Localizable.connectionErrorIntentMissing)
        case .serverMissing:
            return includeCode(inside: Localizable.connectionErrorServerMissing)
        case .timeout:
            return includeCode(inside: Localizable.connectionErrorTimeout)
        }
    }

    public var charCode: FourCharCode {
        switch self {
        case .unexpectedProtocol(let vpnProtocol):
            switch vpnProtocol {
            case .ike:
                return "UXIK"
            case .openVpn(let transport):
                return transport == .tcp ? "UXOT" : "UXOU"
            case .wireGuard(let transport):
                switch transport {
                case .udp:
                    return "UXWU"
                case .tcp:
                    return "UXWT"
                case .tls:
                    return "UXWS"
                }
            }
        case .certAuth:
            return "CRTA"
        case .tunnel:
            return "TUNN"
        case .agent:
            return "AGNT"
        case .preparation:
            return "PREP"
        case .intentMissing:
            return "ITNT"
        case .serverMissing:
            return "SVRM"
        case .timeout(let stage):
            switch stage {
            case .tunnelStartingAndConnecting:
                return "TOTS"
            case .refreshingCertificate:
                return "TORC"
            case .connectingToLocalAgentServer:
                return "TOLA"
            }
        }
    }

    public var underlyingError: Error? {
        switch self {
        case .tunnel(let tunnelError):
            return tunnelError
        case .certAuth(let certAuthError):
            return certAuthError
        case .agent(let agentError):
            return agentError
        case .preparation(let wrapped):
            return wrapped.wrapped
        default:
            return nil
        }
    }
}

extension Alert {
    public static let connectionFailedAlert = Self(message: Localizable.connectionFailed)
}

extension ConnectionError: AlertConvertibleError {
    public var alert: Alert {
        switch self {
        case .certAuth:
            break
        case .tunnel:
            break
        case .agent(let agentError):
            return agentError.alert
        case .preparation(let wrappedError):
            return wrappedError.alert
        case .serverMissing:
            break
        case .intentMissing:
            break
        case .timeout:
            break
        case .unexpectedProtocol(_):
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
        case .agentError(let agentError):
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
        }
        return .connectionFailedAlert
    }
}

extension ConnectionError.WrappedError: AlertConvertibleError {
    public var alert: Alert {
        return .connectionFailedAlert
    }
}
