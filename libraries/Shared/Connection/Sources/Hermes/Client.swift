//
//  Created on 02/04/2025 by adam.
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

import Dependencies
import Sharing
import Foundation
private import DependenciesMacros

private import Network
private import Synchronization

public struct HermesResolver: Hashable {
    public enum Error: Swift.Error {
        case invalidIPAddress
    }

    public static let storagePathComponent: String = "hermes.json"

    public let location: String

    public init(ipAddress: String) throws(Error) {
        guard HermesResolverLocationValidator.isValid(ipAddress) != nil else {
            throw .invalidIPAddress
        }
        self.location = ipAddress
    }
}

extension HermesResolver: Identifiable {
    public var id: String {
        location
    }
}

extension HermesResolver: Codable {}

public struct HermesClient: Sendable {
    public internal(set) var isEnabled: @Sendable () -> SharedReader<Bool>
    public internal(set) var setIsEnabled: @Sendable (Bool) -> Void
    public internal(set) var activeHermesResolvers: @Sendable () -> SharedReader<[HermesResolver]>
    public internal(set) var validateHermesLocation: @Sendable (String) -> Bool
    public internal(set) var addHermesResolver: @Sendable (HermesResolver) -> Bool
    public internal(set) var removeHermesResolver: @Sendable (Int) -> Bool
    public internal(set) var applyDiff: @Sendable (CollectionDifference<HermesResolver>) -> Void

    public init(
        isEnabled: @Sendable @escaping () -> SharedReader<Bool>,
        setIsEnabled: @Sendable @escaping (Bool) -> Void,
        activeHermesResolvers: @Sendable @escaping () -> SharedReader<[HermesResolver]>,
        validateHermesLocation: @Sendable @escaping (String) -> Bool,
        addHermesResolver: @Sendable @escaping (HermesResolver) -> Bool,
        removeHermesResolver: @Sendable @escaping (Int) -> Bool,
        applyDiff: @Sendable @escaping (CollectionDifference<HermesResolver>) -> Void
    ) {
        self.isEnabled = isEnabled
        self.setIsEnabled = setIsEnabled
        self.activeHermesResolvers = activeHermesResolvers
        self.validateHermesLocation = validateHermesLocation
        self.addHermesResolver = addHermesResolver
        self.removeHermesResolver = removeHermesResolver
        self.applyDiff = applyDiff
    }
}

extension HermesClient: TestDependencyKey {
    public static let testValue: HermesClient = {
        return .init {
            return SharedReader(value: false)
        } setIsEnabled: { _ in
            ()
        } activeHermesResolvers: {
            return SharedReader(value: [.proton])
        } validateHermesLocation: { location in
            return HermesResolverLocationValidator.isValid(location) != nil
        } addHermesResolver: { _ in
            false
        } removeHermesResolver: { _ in
            false
        } applyDiff: { _ in
            ()
        }
    }()
}

extension DependencyValues {
    public var hermesClient: HermesClient {
        get { self[HermesClient.self] }
        set { self[HermesClient.self] = newValue }
    }
}

extension HermesResolver {
    public static let proton: HermesResolver = try! HermesResolver(ipAddress: "10.2.0.1")
}

#if DEBUG
extension HermesResolver: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.location = value
    }
}

extension HermesResolver {
    public static let cloudFlare: HermesResolver = "1.1.1.1"
    public static let cloudFlareDoT: HermesResolver = "tls://1.1.1.1"
    public static let cloudFlareDoH: HermesResolver = "https://1.1.1.1/dns-query"
    public static let google: HermesResolver = "8.8.8.8"
    public static let googleDoT: HermesResolver = "tls://8.8.8.8"
    public static let googleDoH: HermesResolver = "https://8.8.8.8/dns-query"
    public static let quadNine: HermesResolver = "9.9.9.9"
}
#endif
