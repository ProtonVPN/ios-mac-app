//
//  Created on 2022-05-17.
//
//  Copyright (c) 2022 Proton AG
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
import Domain
import Ergonomics
import Foundation
import NetworkExtension
import Strings

public protocol ProviderMessage: Equatable {
    var asData: Data { get }

    static func decode(data: Data) throws -> Self
}

public protocol ProviderRequest: ProviderMessage {
    associatedtype Response: ProviderMessage
}

public protocol ProviderMessageSender: AnyObject {
    func send<R>(_ message: R, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R: ProviderRequest
}

public extension ProviderMessageSender {
    func send<R: ProviderRequest>(_ message: R) async throws -> R.Response {
        try await withCheckedThrowingContinuation { continuation in
            send(message) {
                continuation.resume(with: $0)
            }
        }
    }
}

@CasePathable
public enum ProviderMessageError: Error, Equatable {
    case cancelled
    case sendingError(SendingError)
    case noDataReceived
    case decodingError
    case unknownRequest
    case unknownResponse
    case remoteError(message: String)

    @CasePathable
    public enum SendingError: Error, Equatable {
        /// We normally have the `TunnelManager` loaded.
        /// If not, the method to retrieve it can throw while we are loading the manager from preferences.
        case managerUnavailable(Error)

        /// According to the Apple docs, possible errors include:
        /// - NEVPNErrorConfigurationInvalid
        /// - NEVPNErrorConfigurationDisabled
        case internalSendFailed(Error)

        public static func == (lhs: SendingError, rhs: SendingError) -> Bool {
            switch (lhs, rhs) {
            case (.managerUnavailable, .managerUnavailable):
                true

            case (.internalSendFailed, .internalSendFailed):
                true

            default:
                false
            }
        }
    }
}

extension ProviderMessageError: ProtonVPNError {
    public static let errorDomain = "ProviderMessageErrorDomain"

    public var errorDescription: String? {
        includeCode(inside: Localizable.providerMessageError)
    }

    public var charCode: FourCharCode {
        switch self {
        case .noDataReceived:
            "NRCV"
        case .cancelled:
            "CANC"
        case .decodingError:
            "MDCD"
        case .sendingError:
            "MSND"
        case .unknownRequest:
            "UNRQ"
        case .unknownResponse:
            "UNRS"
        case .remoteError:
            "RMOT"
        }
    }
}
