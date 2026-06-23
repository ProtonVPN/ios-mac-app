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

/// A ``ProtonVPNError`` that can be reconstructed from its ``FourCharCode`` and ErrorDomain alone.
public protocol ReconstructableError: ProtonVPNError {
    init?(charCode: FourCharCode)
}

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

    /// Recover this as a concrete ``ReconstructableError`` error of type `E` when the domain matches and the code is one
    /// `E` recognises; otherwise `nil` (handle it generically via `domain`/`code`).
    public func decoded<E: ReconstructableError>(as _: E.Type) -> E? {
        guard domain == E.errorDomain else { return nil }
        return E(charCode: code)
    }
}

extension ExtensionError: CustomStringConvertible {
    public var description: String {
        "\(domain) (code \(code))"
    }
}
