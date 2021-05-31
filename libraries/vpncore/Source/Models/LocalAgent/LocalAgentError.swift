//
//  LocalAgentError.swift
//  Core
//
//  Created by Igor Kulman on 24.05.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
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
    case policyViolation
    case userTorrentNotAllowed
    case userBadBehavior
}

extension LocalAgentError {
    // swiftlint:disable cyclomatic_complexity
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
        case consts.errorCodePolicyViolation:
            return .policyViolation
        case consts.errorCodeUserTorrentNotAllowed:
            return .userTorrentNotAllowed
        case consts.errorCodeUserBadBehavior:
            return .userBadBehavior
        default:
            PMLog.ET("Trying to parse unknown local agent error \(code)")
            return nil
        }
    }
}
