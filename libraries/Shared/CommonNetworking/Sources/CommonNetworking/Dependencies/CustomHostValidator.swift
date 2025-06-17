//
//  Created on 10/06/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
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
import Dependencies

/// Used to ensure the app is only used with appropriate API hosts in production
public enum ReleaseHostValidator {
    public static func validate(customHost: String) throws (CustomHostValidator.ValidationFailure) {
        let controlledDomains = ["proton.black"]
        // Only allow custom hosts using a domain we control.
        guard let url = URL(string: customHost) else {
            throw .invalidURL
        }

        guard let host = url.host else {
            throw .invalidHost
        }

        let isControlledDomain = controlledDomains.contains { host.hasSuffix($0) }
        guard isControlledDomain else {
            throw .uncontrolledDomain
        }
    }
}

public struct CustomHostValidator {
    public private(set) var validate: (_ customHost: String) throws(ValidationFailure) -> Void

    public enum ValidationFailure: Error, Equatable, CustomStringConvertible {
        case invalidURL
        case invalidHost
        case uncontrolledDomain

        public var description: String {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidHost:
                return "Invalid Host"
            case .uncontrolledDomain:
                return "Uncontrolled Domain"
            }
        }
    }
}

extension CustomHostValidator: TestDependencyKey {
    public static let debug = CustomHostValidator(validate: { log.info("Allowing host: \($0)", category: .api) })
    public static let release = CustomHostValidator(validate: ReleaseHostValidator.validate)

    // If we fail to implement or link against a `DependencyKey` with a `liveValue`, we will fall back to using the
    // release host validator. This is an intentional safety measure
    public static let testValue: CustomHostValidator = .release
}

extension DependencyValues {
    public var customHostValidator: CustomHostValidator {
        get { self[CustomHostValidator.self] }
        set { self[CustomHostValidator.self] = newValue }
    }
}
