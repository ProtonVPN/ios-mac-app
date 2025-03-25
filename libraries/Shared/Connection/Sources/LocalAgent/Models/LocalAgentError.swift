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

import Foundation
import CasePaths
import GoLibs
import let CoreConnection.log
import Domain
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

@CasePathable
public enum LocalAgentError: ProtonVPNError {
    public static var errorDomain: String { "LocalAgentRemoteError" }

    case restrictedServer
    case certificateExpired
    case certificateRevoked
    case maxSessionsUnknown
    case maxSessionsFree
    case maxSessionsBasic
    case maxSessionsPlus
    case maxSessionsVisionary
    case maxSessionsPro
    case keyUsedMultipleTimes
    case serverError
    case policyViolationLowPlan
    case policyViolationDelinquent
    case userTorrentNotAllowed
    case userBadBehavior
    case guestSession
    case badCertificateSignature
    case certificateNotProvided
    case serverSessionDoesNotMatch
    case systemError(LocalAgentErrorSystemError)
    case unknown(code: Int)

    public var charCode: FourCharCode {
        switch self {
        case .restrictedServer:
            return "LRXS"
        case .certificateExpired:
            return "LCRX"
        case .certificateRevoked:
            return "LCRV"
        case .maxSessionsUnknown:
            return "LMSU"
        case .maxSessionsFree:
            return "LMSF"
        case .maxSessionsBasic:
            return "LMSB"
        case .maxSessionsPlus:
            return "LMS+"
        case .maxSessionsVisionary:
            return "LMSV"
        case .maxSessionsPro:
            return "LMSP"
        case .keyUsedMultipleTimes:
            return "LKMT"
        case .serverError:
            return "LSRV"
        case .policyViolationLowPlan:
            return "LPVL"
        case .policyViolationDelinquent:
            return "LPVD"
        case .userTorrentNotAllowed:
            return "LTRN"
        case .userBadBehavior:
            return "LUBB"
        case .guestSession:
            return "LGSX"
        case .badCertificateSignature:
            return "LBCS"
        case .certificateNotProvided:
            return "LCNP"
        case .serverSessionDoesNotMatch:
            return "LSNM"
        case .systemError(let systemError):
            return "LSER"
        case .unknown:
            return "LUNK"
        }
    }

    public var underlyingError: Error? {
        switch self {
        case .systemError(let error):
            return error
        case .unknown(let code):
            return NSError(domain: Self.errorDomain, code: code)
        default:
            return nil
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
