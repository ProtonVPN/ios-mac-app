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

import Foundation
import NetworkExtension
import Ergonomics
import Domain
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

extension ProviderMessageSender {
    public func send<R: ProviderRequest>(_ message: R) async throws -> R.Response {
        try await withCheckedThrowingContinuation { continuation in
            send(message) {
                continuation.resume(with: $0)
            }
        }
    }
}

public enum ProviderMessageError: Error {
    case noDataReceived
    case decodingError
    case sendingError
    case unknownRequest
    case unknownResponse
    case remoteError(message: String)
}

extension ProviderMessageError: ProtonVPNError {
    public static let errorDomain = "ProviderMessageErrorDomain"

    public var errorDescription: String? {
        switch self {
        case .noDataReceived:
            return Localizable.providerMessageErrorNoDataReceived
        case .decodingError:
            return Localizable.providerMessageErrorDecodingError
        case .sendingError:
            return Localizable.providerMessageErrorSendingError
        case .unknownRequest:
            return Localizable.providerMessageErrorUnknownRequest
        case .unknownResponse:
            return Localizable.providerMessageErrorUnknownResponse
        case .remoteError(let message):
            return Localizable.providerMessageErrorRemoteError(message)
        }
    }

    public var charCode: String {
        switch self {
        case .noDataReceived:
            return "NRCV"
        case .decodingError:
            return "MDCD"
        case .sendingError:
            return "MSND"
        case .unknownRequest:
            return "UNRQ"
        case .unknownResponse:
            return "UNRS"
        case .remoteError:
            return "RMOT"
        }
    }
}
