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
    @Shared(.hermesResolvers) private static var hermesResolvers
    @Shared(.hermesEnabled) private static var hermesEnabled = .defaultValue

    public static let liveValue: HermesClient = .init {
        $hermesEnabled.read { $0.boolValue }
    } setIsEnabled: { newValue in
        $hermesEnabled.withLock { $0 = .fromBoolValue(newValue) }
    } activeHermesResolvers: {
        $hermesResolvers.read { $0 }
    } validateHermesLocation: { location in
        HermesResolverLocationValidator.isValidIPv4(location) != nil
    } addHermesResolver: { newResolver in
        let newResolvers = hermesResolvers + [newResolver]
        $hermesResolvers.withLock { $0 = newResolvers }
        return true
    } removeHermesResolver: { index in
        var copy = hermesResolvers
        copy.remove(at: index)
        $hermesResolvers.withLock { $0 = copy }
        return true
    } applyDiff: { diff in
        var copy = hermesResolvers
        copy = copy.applying(diff) ?? copy
        $hermesResolvers.withLock { $0 = copy }
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
            let newResolvers = hermesResolvers + [newResolver]
            $hermesResolvers.withLock { $0 = newResolvers }
            return true
        } removeHermesResolver: { index in
            @Shared(.testHermesResolvers) var hermesResolvers
            var copy = hermesResolvers
            copy.remove(at: index)
            $hermesResolvers.withLock { $0 = copy }
            return true
        } applyDiff: { diff in
            @Shared(.testHermesResolvers) var hermesResolvers
            var copy = hermesResolvers
            copy = copy.applying(diff) ?? copy
            $hermesResolvers.withLock { $0 = copy }
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
