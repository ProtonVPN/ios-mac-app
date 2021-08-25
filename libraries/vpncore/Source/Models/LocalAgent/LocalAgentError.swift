//
//  LocalAgentError.swift
//  Core
//
//  Created by Igor Kulman on 24.05.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import WireguardCrypto

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
