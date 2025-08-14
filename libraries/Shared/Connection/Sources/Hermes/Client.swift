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

import Domain

import Dependencies
import Foundation
import Sharing
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
        guard HermesResolverLocationValidator.isValidIPv4(ipAddress) != nil else {
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

public extension DependencyValues {
    var hermesClient: HermesClient {
        get { self[HermesClient.self] }
        set { self[HermesClient.self] = newValue }
    }
}

// MARK: - Testing

private extension SharedKey where Self == InMemoryKey<Bool>.Default {
    static var hermesEnabled: Self {
        self[.inMemory("HermesFeatureEnabled"), default: false]
    }
}

private extension SharedKey where Self == InMemoryKey<[HermesResolver]>.Default {
    static var hermesResolvers: Self {
        self[.inMemory("HermesResolvers"), default: []]
    }
}

extension HermesClient: TestDependencyKey {
    public static let testValue: HermesClient = {
        @Shared(.hermesEnabled) var enabled

        return .init {
            SharedReader(wrappedValue: false, .hermesEnabled)
        } setIsEnabled: { newValue in
            @Shared(.hermesEnabled) var hermesEnabled: Bool
            $hermesEnabled.withLock { $0 = newValue }
            AppEvent.hermes.post()
        } activeHermesResolvers: {
            SharedReader(wrappedValue: [], .hermesResolvers)
        } validateHermesLocation: { location in
            HermesResolverLocationValidator.isValidIPv4(location) != nil
        } addHermesResolver: { newResolver in
            @Shared(.hermesResolvers) var hermesResolvers
            let newResolvers = hermesResolvers + [newResolver]
            $hermesResolvers.withLock { $0 = newResolvers }
            AppEvent.hermes.post()
            return true
        } removeHermesResolver: { index in
            @Shared(.hermesResolvers) var hermesResolvers
            var copy = hermesResolvers
            copy.remove(at: index)
            $hermesResolvers.withLock { $0 = copy }
            AppEvent.hermes.post()
            return true
        } applyDiff: { diff in
            @Shared(.hermesResolvers) var hermesResolvers
            var copy = hermesResolvers
            copy = copy.applying(diff) ?? copy
            $hermesResolvers.withLock { $0 = copy }
            AppEvent.hermes.post()
        }
    }()
}

// MARK: - Definitions

public extension HermesResolver {
    static let proton: HermesResolver = try! HermesResolver(ipAddress: "10.2.0.1")
}

public extension HermesClient {
    var currentResolvers: [HermesResolver] {
        let hermesIsEnabled: Bool = isEnabled().wrappedValue

        var hermesResolvers: [HermesResolver] = [.proton]
        if hermesIsEnabled {
            hermesResolvers.insert(contentsOf: activeHermesResolvers().wrappedValue, at: 0)
        }

        return hermesResolvers
    }
}

#if DEBUG
    extension HermesResolver: ExpressibleByStringLiteral {
        public init(stringLiteral value: StringLiteralType) {
            self.location = value
        }
    }

    public extension HermesResolver {
        static let cloudFlare: HermesResolver = "1.1.1.1"
        static let cloudFlareDoT: HermesResolver = "tls://1.1.1.1"
        static let cloudFlareDoH: HermesResolver = "https://1.1.1.1/dns-query"
        static let google: HermesResolver = "8.8.8.8"
        static let googleDoT: HermesResolver = "tls://8.8.8.8"
        static let googleDoH: HermesResolver = "https://8.8.8.8/dns-query"
        static let quadNine: HermesResolver = "9.9.9.9"
    }
#endif
