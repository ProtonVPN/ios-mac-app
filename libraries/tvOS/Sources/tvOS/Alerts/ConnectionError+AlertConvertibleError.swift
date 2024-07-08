//
//  Created on 08/07/2024.
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
import Connection
import LocalAgent
import Strings

extension ConnectionError: AlertConvertibleError {
    public var alert: AlertService.Alert {
        switch self {
        case .certAuth:
            break
        case .tunnel:
            break
        case .agent(let agentError):
            return agentError.alert
        case .serverMissing:
            break
        case .timeout:
            break
        }
        return ConnectionFailedAlert()
    }
}

extension LocalAgentConnectionError: AlertConvertibleError {
    public var alert: AlertService.Alert {
        switch self {
        case .failedToEstablishConnection:
            break
        case .agentError(let agentError):
            return agentError.alert
        case .serverCertificateError:
            break
        }
        return ConnectionFailedAlert()
    }
}

extension LocalAgentError: AlertConvertibleError {
    public var alert: AlertService.Alert {
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
            return .init(title: .init(title), message: .init(message))
        case .keyUsedMultipleTimes:
            break
        case .serverError:
            let title = Localizable.localAgentServerErrorTitle
            let message = Localizable.localAgentServerErrorMessage
            return .init(title: .init(title), message: .init(message))
        case .policyViolationLowPlan:
            let title = Localizable.localAgentPolicyViolationErrorTitle
            let message = Localizable.localAgentPolicyViolationErrorMessage
            return .init(title: .init(title), message: .init(message))
        case .policyViolationDelinquent:
            let title = Localizable.delinquentUserTitle
            let message = Localizable.delinquentUserDescription
            return .init(title: .init(title), message: .init(message))
        case .userTorrentNotAllowed:
            break // Possible disconnection error, but no specific message to the user
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
        return ConnectionFailedAlert()
    }
}
