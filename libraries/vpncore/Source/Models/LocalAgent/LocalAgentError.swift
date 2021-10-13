//
//  LocalAgentError.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import WireguardSRP

enum LocalAgentError: Error {
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
}

extension LocalAgentError {
    // swiftlint:disable cyclomatic_complexity function_body_length
    static func from(code: Int) -> LocalAgentError? {
        guard let consts = LocalAgentConstants() else {
            PMLog.ET("Failed to create local agent constants")
            return nil
        }

        switch code {
        case consts.errorCodeRestrictedServer:
            return .restrictedServer
        case consts.errorCodeCertificateExpired:
            return .certificateExpired
        case consts.errorCodeCertificateRevoked:
            return .certificateRevoked
        case consts.errorCodeMaxSessionsUnknown:
            return .maxSessionsUnknown
        case consts.errorCodeMaxSessionsFree:
            return .maxSessionsFree
        case consts.errorCodeMaxSessionsBasic:
            return .maxSessionsBasic
        case consts.errorCodeMaxSessionsPlus:
            return .maxSessionsPlus
        case consts.errorCodeMaxSessionsVisionary:
            return .maxSessionsVisionary
        case consts.errorCodeMaxSessionsPro:
            return .maxSessionsPro
        case consts.errorCodeKeyUsedMultipleTimes:
            return .keyUsedMultipleTimes
        case consts.errorCodeServerError:
            return .serverError
        case consts.errorCodePolicyViolationLowPlan:
            return .policyViolationLowPlan
        case consts.errorCodePolicyViolationDelinquent:
            return .policyViolationDelinquent
        case consts.errorCodeUserTorrentNotAllowed:
            return .userTorrentNotAllowed
        case consts.errorCodeUserBadBehavior:
            return .userBadBehavior
        case consts.errorCodeGuestSession:
            return .guestSession
        case consts.errorCodeBadCertSignature:
            return .badCertificateSignature
        case consts.errorCodeCertNotProvided:
            return .certificateNotProvided
        default:
            PMLog.ET("Trying to parse unknown local agent error \(code)")
            return nil
        }
    }
}
