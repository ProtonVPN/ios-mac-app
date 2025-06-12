//
//  Created on 03/06/2024.
//
//  Copyright (c) 2024 Proton AG
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
import let CoreConnection.log
import Domain
import Foundation
import GoLibs
import Strings

public enum LocalAgentErrorSystemError: FourCharCode, ProtonVPNError, AlertConvertibleError {
    public static let errorDomain = "LocalAgentSystemErrorDomain"

    case splitTcp = "LAST"
    case netshield = "LANS"
    case nonRandomizedNat = "LANN"
    case safeMode = "LASM"

    public var alert: Alert {
        let title, message: String
        switch self {
        case .splitTcp:
            title = Localizable.vpnAcceleratorTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.vpnAcceleratorTitle)
        case .netshield:
            title = Localizable.netshieldTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.netshieldTitle)
        case .nonRandomizedNat:
            title = Localizable.moderateNatTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.moderateNatTitle)
        case .safeMode:
            title = Localizable.nonStandardPortsTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.nonStandardPortsTitle)
        }

        return Alert(title: title, message: message)
    }
}

/// A collection of errors that can be reported by the Local Agent.
/// Each case is defined with an appropriate resolution strategy.
/// For more information, check [Shared VPN Libraries](https://github.com/ProtonVPN/go-vpn-lib/tree/master/localAgent)
/// and [Local Agent Error Codes](https://protonvpn.gitlab-pages.protontech.ch/knowledge-base/Certificates-and-Local-Agent/LocalAgent-error-codes)
@CasePathable

public enum LocalAgentError: ProtonVPNError {
    public static var errorDomain: String { "LocalAgentRemoteError" }

    /// Unexpected: only seen with legacy username 'guest'
    case guestSession
    /// Certificate has expired: renew it, and try to reconnect
    case certificateExpired
    /// Certificate has been revoked: regenerate keys, request a certificate and try to reconnect
    case certificateRevoked
    /// Regenerate keys and try to reconnect
    case keyUsedMultipleTimes
    /// Restricted server, unable to verify the certificate yet - wait or try another server
    case restrictedServer
    /// Regenerate keys and try to reconnect
    case badCertificateSignature
    /// Unexpected: try to reconnect with existing certificate
    case certificateNotProvided

    /// Disconnect, or upgrade plan
    case maxSessionsUnknown
    /// Disconnect, or upgrade plan
    case maxSessionsFree
    /// Disconnect, or upgrade plan
    case maxSessionsBasic
    /// Disconnect, or upgrade plan
    case maxSessionsPlus
    /// Disconnect, or upgrade plan
    case maxSessionsVisionary
    /// Disconnect, or upgrade plan
    case maxSessionsPro

    /// Disconnect and try another server
    case serverError

    /// Try another server or upgrade plan
    case policyViolationLowPlan
    /// Try another server, disable features or upgrade plan
    case policyViolationDelinquent

    /// Unexpected
    case userTorrentNotAllowed

    /// Bad user behaviour
    case userBadBehavior

    /// Use the correct ed25519/x25519 key
    case serverSessionDoesNotMatch

    /// Feature could not be set - try again or on another server
    case systemError(LocalAgentErrorSystemError)
    case unknown(code: Int)

    public var charCode: FourCharCode {
        switch self {
        case .restrictedServer:
            "LRXS"
        case .certificateExpired:
            "LCRX"
        case .certificateRevoked:
            "LCRV"
        case .maxSessionsUnknown:
            "LMSU"
        case .maxSessionsFree:
            "LMSF"
        case .maxSessionsBasic:
            "LMSB"
        case .maxSessionsPlus:
            "LMS+"
        case .maxSessionsVisionary:
            "LMSV"
        case .maxSessionsPro:
            "LMSP"
        case .keyUsedMultipleTimes:
            "LKMT"
        case .serverError:
            "LSRV"
        case .policyViolationLowPlan:
            "LPVL"
        case .policyViolationDelinquent:
            "LPVD"
        case .userTorrentNotAllowed:
            "LTRN"
        case .userBadBehavior:
            "LUBB"
        case .guestSession:
            "LGSX"
        case .badCertificateSignature:
            "LBCS"
        case .certificateNotProvided:
            "LCNP"
        case .serverSessionDoesNotMatch:
            "LSNM"
        case .systemError:
            "LSER"
        case .unknown:
            "LUNK"
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .systemError(error):
            error
        case let .unknown(code):
            NSError(domain: Self.errorDomain, code: code)
        default:
            nil
        }
    }
}

extension LocalAgentError {
    // swiftlint:disable cyclomatic_complexity function_body_length
    static func from(code: Int) -> LocalAgentError {
        switch code {
        case localAgentConsts.errorCodeRestrictedServer:
            return .restrictedServer
        case localAgentConsts.errorCodeCertificateExpired:
            return .certificateExpired
        case localAgentConsts.errorCodeCertificateRevoked:
            return .certificateRevoked
        case localAgentConsts.errorCodeMaxSessionsUnknown:
            return .maxSessionsUnknown
        case localAgentConsts.errorCodeMaxSessionsFree:
            return .maxSessionsFree
        case localAgentConsts.errorCodeMaxSessionsBasic:
            return .maxSessionsBasic
        case localAgentConsts.errorCodeMaxSessionsPlus:
            return .maxSessionsPlus
        case localAgentConsts.errorCodeMaxSessionsVisionary:
            return .maxSessionsVisionary
        case localAgentConsts.errorCodeMaxSessionsPro:
            return .maxSessionsPro
        case localAgentConsts.errorCodeKeyUsedMultipleTimes:
            return .keyUsedMultipleTimes
        case localAgentConsts.errorCodeServerError:
            return .serverError
        case localAgentConsts.errorCodePolicyViolationLowPlan:
            return .policyViolationLowPlan
        case localAgentConsts.errorCodePolicyViolationDelinquent:
            return .policyViolationDelinquent
        case localAgentConsts.errorCodeUserTorrentNotAllowed:
            return .userTorrentNotAllowed
        case localAgentConsts.errorCodeUserBadBehavior:
            return .userBadBehavior
        case localAgentConsts.errorCodeGuestSession:
            return .guestSession
        case localAgentConsts.errorCodeBadCertSignature:
            return .badCertificateSignature
        case localAgentConsts.errorCodeCertNotProvided:
            return .certificateNotProvided
        case 86202: // Server session doesn't match: Use the correct ed25519/x25519 key
            return .serverSessionDoesNotMatch
        case 86211:
            return .systemError(.netshield)
        case 86226:
            return .systemError(.nonRandomizedNat)
        case 86231:
            return .systemError(.splitTcp)
        case 86241:
            return .systemError(.safeMode)
        default:
            log.error("Trying to parse unknown local agent error \(code)", category: .localAgent)
            return .unknown(code: code)
        }
    }
}
