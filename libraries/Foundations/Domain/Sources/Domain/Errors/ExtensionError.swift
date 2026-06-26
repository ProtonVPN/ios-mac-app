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
public struct ExtensionError: Error, Equatable, Sendable {
    public let domain: String
    public let code: UInt32

    public init(domain: String, code: UInt32) {
        self.domain = domain
        self.code = code
    }

    /// Recover ``ProtonVPNError``'s that are happy to be represented as a raw `FourCharCode`.
    public func decoded<E: RawRepresentable<FourCharCode> & ProtonVPNError>(as _: E.Type) -> E? {
        guard domain == E.errorDomain else { return nil }
        return E(rawValue: code)
    }
}

extension ExtensionError: CustomStringConvertible {
    public var description: String {
        "\(domain) (code \(code))"
    }
}
