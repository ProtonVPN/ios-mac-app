//
//  Created on 19.02.2025.
//
//  Copyright (c) 2025 Proton AG
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

public protocol ProtonVPNError: LocalizedError, CustomNSError {
    /// A 4-character code uniquely representing the error across the codebase.
    ///
    /// - Invariant: the string **must** be 4 characters long or it may cause a runtime error.
    /// - Example: an enum case like ".connectionFailed" could be represented as "CNFL".
    var charCode: FourCharCode { get }
}

public extension ProtonVPNError {
    static var errorDomain: String {
        "ProtonVPNErrorDomain"
    }

    var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription ?? "\(Self.errorDomain) \(String(describing: errorCode))"]
    }

    var errorCode: Int {
        Int(charCode)
    }
}

public extension ProtonVPNError where Self: RawRepresentable<FourCharCode> {
    var charCode: FourCharCode { rawValue }
}

extension FourCharCode: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: StaticString) {
        assert(value.utf8CodeUnitCount == 4, "Char pattern must have exactly 4 characters")
        assert(value.isASCII, "Char pattern must be ASCII string")

        var result: FourCharCode = 0
        value.withUTF8Buffer { valueBuffer in
            withUnsafeMutableBytes(of: &result) { resultBuffer in
                resultBuffer.copyBytes(from: valueBuffer)
            }
        }

        self = result
    }
}
