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

public protocol ProviderMessage {
    var asData: Data { get }

    static func decode(data: Data) throws -> Self
}

public protocol ProviderRequest: ProviderMessage {
    associatedtype Response: ProviderMessage
}

public protocol ProviderMessageSender {
    func send<R>(_ message: R, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R: ProviderRequest
}

public enum ProviderMessageError: Error {
    case noDataReceived
    case decodingError
    case sendingError
    case unknownMessage
}

extension NETunnelProviderSession: ProviderMessageSender {
    public func send<R>(_ message: R, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R: ProviderRequest {
        do {
            try sendProviderMessage(message.asData) { maybeData in
                guard let data = maybeData else {
                    completion?(.failure(.noDataReceived))
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
            completion?(.failure(.sendingError))
        }
    }
}
