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

private import DependenciesMacros
import Dependencies
import Domain
import Foundation
import Sharing
import VPNAppCore

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

private extension SharedKey where Self == FileStorageKey<[HermesResolver]>.Default {
    static var hermesResolvers: Self {
        self[.fileStorage(.documentsDirectory.appending(component: HermesResolver.storagePathComponent)), default: []]
    }
}

private extension SharedKey where Self == AuthorizedFeatureSharedKey<HermesFeature> {
    static var hermesEnabled: Self {
        AuthorizedFeatureSharedKey()
    }
}

#if DEBUG

    // MARK: - Testing

    private extension SharedKey where Self == InMemoryKey<Bool>.Default {
        static var testHermesEnabled: Self {
            self[.inMemory("HermesFeatureEnabled"), default: false]
        }
    }

    private extension SharedKey where Self == InMemoryKey<[HermesResolver]>.Default {
        static var testHermesResolvers: Self {
            self[.inMemory("HermesResolvers"), default: []]
        }
    }
#endif

extension HermesClient: DependencyKey {
    // Shared state is deliberately constructed inside each closure, never in static properties
    public static let liveValue: HermesClient = .init {
        @Shared(.hermesEnabled) var hermesEnabled = .defaultValue
        return $hermesEnabled.read { $0.boolValue }
    } setIsEnabled: { newValue in
        @Shared(.hermesEnabled) var hermesEnabled = .defaultValue
        $hermesEnabled.withLock { $0 = .fromBoolValue(newValue) }
    } activeHermesResolvers: {
        @Shared(.hermesResolvers) var hermesResolvers
        return $hermesResolvers.read { $0 }
    } validateHermesLocation: { location in
        HermesResolverLocationValidator.isValidIPv4(location) != nil
    } addHermesResolver: { newResolver in
        @Shared(.hermesResolvers) var hermesResolvers
        // Mutate inside the lock: a read-copy-write across separate statements loses updates when
        // two mutations race.
        $hermesResolvers.withLock { $0.append(newResolver) }
        return true
    } removeHermesResolver: { index in
        @Shared(.hermesResolvers) var hermesResolvers
        var removed = false
        $hermesResolvers.withLock { resolvers in
            guard resolvers.indices.contains(index) else { return }
            resolvers.remove(at: index)
            removed = true
        }
        return removed
    } applyDiff: { diff in
        @Shared(.hermesResolvers) var hermesResolvers
        $hermesResolvers.withLock { $0 = $0.applying(diff) ?? $0 }
    }

    #if DEBUG
        public static let testValue: HermesClient = .init {
            SharedReader(wrappedValue: false, .testHermesEnabled)
        } setIsEnabled: { newValue in
            @Shared(.testHermesEnabled) var hermesEnabled: Bool
            $hermesEnabled.withLock { $0 = newValue }
        } activeHermesResolvers: {
            SharedReader(wrappedValue: [], .testHermesResolvers)
        } validateHermesLocation: { location in
            HermesResolverLocationValidator.isValidIPv4(location) != nil
        } addHermesResolver: { newResolver in
            @Shared(.testHermesResolvers) var hermesResolvers
            $hermesResolvers.withLock { $0.append(newResolver) }
            return true
        } removeHermesResolver: { index in
            @Shared(.testHermesResolvers) var hermesResolvers
            var removed = false
            $hermesResolvers.withLock { resolvers in
                guard resolvers.indices.contains(index) else { return }
                resolvers.remove(at: index)
                removed = true
            }
            return removed
        } applyDiff: { diff in
            @Shared(.testHermesResolvers) var hermesResolvers
            $hermesResolvers.withLock { $0 = $0.applying(diff) ?? $0 }
        }
    #endif
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

private extension HermesFeature {
    static func fromBoolValue(_ value: Bool) -> HermesFeature {
        value ? .on : .off
    }

    var boolValue: Bool {
        switch self {
        case .off:
            false
        case .on:
            true
        }
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
