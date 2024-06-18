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

extension ProviderMessageSender {
    public func send<R: ProviderRequest>(_ message: R) async throws -> R.Response {
        try await withCheckedThrowingContinuation { continuation in
            send(message, completion: continuation.resume(with:))
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
