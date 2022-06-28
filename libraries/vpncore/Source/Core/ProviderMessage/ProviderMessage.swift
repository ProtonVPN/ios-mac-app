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

public enum ProviderMessageError: Error {
    case noDataReceived
    case decodingError
    case sendingError
    case unknownRequest
    case unknownResponse
    case remoteError(message: String)
}

extension NETunnelProviderSessionWrapper {
    public func send<R>(_ message: R, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R: ProviderRequest {
        send(message, maxRetries: 5, completion: completion)
    }

    private func send<R>(_ message: R, maxRetries: Int, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R: ProviderRequest {
        do {
            try sendProviderMessage(message.asData) { [weak self] maybeData in
                guard let data = maybeData else {
                    // From documentation: "If this method can’t start sending the message it throws an error. If an
                    // error occurs while sending the message or returning the result, `nil` should be sent to the
                    // response handler as notification." If we encounter an xpc error, try sleeping for a second and
                    // then trying again - the extension could still be launching, or we could be coming out of sleep.
                    // If we retry enough times and still get nowhere, return an error.

                    guard maxRetries > 0 else {
                        completion?(.failure(.noDataReceived))
                        return
                    }

                    sleep(1)
                    self?.send(message, maxRetries: maxRetries - 1, completion: completion)
                    return
                }

                do {
                    let response = try R.Response.decode(data: data)
                    completion?(.success(response))
                } catch {
                    completion?(.failure(.decodingError))
                }
            }
        } catch {
            log.error("Received error while attempting to send provider message: \(error)")
            completion?(.failure(.sendingError))
        }
    }
}
