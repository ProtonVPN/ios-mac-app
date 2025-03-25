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

public protocol ProtonVPNError: LocalizedError, CustomNSError, CustomStringConvertible, CustomDebugStringConvertible {
    /// A 4-character code uniquely representing the error across the codebase.
    ///
    /// - Invariant: the string **must** be 4 characters long or it may cause a runtime error.
    /// - Example: an enum case like ".connectionFailed" could be represented as "CNFL".
    var charCode: FourCharCode { get }

    var underlyingError: Error? { get }

    var extraUserInfo: [String: Any]? { get }
}

public extension ProtonVPNError {
    static var errorDomain: String {
        "ProtonVPNErrorDomain"
    }

    var extraUserInfo: [String: Any]? { nil }
    var underlyingError: Error? { nil }

    var errorUserInfo: [String: Any] {
        var result: [String: Any] = [NSLocalizedDescriptionKey: errorDescription ?? description]
        if let underlyingError {
            result[NSUnderlyingErrorKey] = underlyingError
        }
        if let extraUserInfo {
            result = result.merging(extraUserInfo, uniquingKeysWith: { _, rhs in rhs })
        }
        return result
    }

    var errorCode: Int {
        Int(charCode)
    }

    var errorCodeString: String {
        "0x\(String(charCode, radix: 16))"
    }

    func includeCode(inside localizationClosure: (String) -> String) -> String {
        localizationClosure(errorCodeString)
    }

    var description: String {
        "\(Self.errorDomain) \(errorCodeString)"
    }

    var debugDescription: String {
        var result = "\(Self.errorDomain) \(charCode.debugDescription)"

        var userInfo = errorUserInfo
        userInfo.removeValue(forKey: NSLocalizedDescriptionKey)
        let underlyingError = userInfo.removeValue(forKey: NSUnderlyingErrorKey)

        if !userInfo.isEmpty {
            result += ", userInfo: \(userInfo as AnyObject)"
        }

        if let underlyingError {
            if let protonVpnError = underlyingError as? ProtonVPNError {
                result += " (\(protonVpnError.debugDescription))"
            } else {
                result += " (\(String(describing: underlyingError)))"
            }
        }

        return result
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

extension FourCharCode: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        let data = withUnsafeBytes(of: self) { valueBuffer in
            guard let valuePointer = valueBuffer.baseAddress else {
                return Data()
            }
            return Data(bytes: valuePointer, count: MemoryLayout<FourCharCode>.size)
        }
        return String(data: data, encoding: .ascii) ?? String(describing: self)
    }
}
