//
//  Created on 24/06/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

/// The marshalled type for errors reported by the network extension over the ``IPCErrorPayload`` ``RawChannel``.
/// Provides a helper method for ``ProtonVPNError``s that can be initialized from just a char code, so that the
/// connection layer can consume error values idiomatically.
public struct ExtensionError: Error, Identifiable, Equatable, Sendable {
    /// The id of the request this error relates to, if any.
    public let id: UUID?
    public let domain: String
    public let code: UInt32

    public init(domain: String, code: UInt32, requestId: UUID? = nil) {
        self.id = requestId
        self.domain = domain
        self.code = code
    }

    /// Recover ``ProtonVPNError``'s that are happy to be represented as a raw `FourCharCode` (or any other binary type)
    public func decoded<T: BinaryInteger, E: RawRepresentable<T> & CustomNSError>(as _: E.Type) -> E? {
        guard domain == E.errorDomain else { return nil }
        return E(rawValue: T(code))
    }
}

extension ExtensionError: CustomStringConvertible {
    public var description: String {
        "\(domain) (code \(code) id \(id?.uuidString ?? "nil"))"
    }
}
