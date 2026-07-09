//
//  Created on 11/06/2026 by Max Kupetskyi.
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

import Dependencies
import Foundation
import Sharing

public extension SharedKey where Self == AppStorageKey<VpnProtocol>.Default {
    static var vpnProtocol: Self {
        Self[.appStorage(ConnectionProtocolSharedKey.vpnProtocolKey), default: VpnProtocol()]
    }
}

public extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var smartProtocol: Self {
        Self[
            .appStorage(ConnectionProtocolSharedKey.smartProtocolKey),
            default: ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault
        ]
    }
}

// MARK: - Derived connection protocol

public extension SharedKey where Self == ConnectionProtocolSharedKey.Default {
    /// The user's effective ``ConnectionProtocol``, derived from the two underlying stored values
    /// (`smartProtocol` + `vpnProtocol`).
    static var connectionProtocol: Self {
        Self[ConnectionProtocolSharedKey(), default: .smartProtocol]
    }
}

/// All protocols that are supported
public func currentProtocolSupport() -> ProtocolSupport {
    @SharedReader(.connectionProtocol) var connectionProtocol
    switch connectionProtocol {
    case .smartProtocol:
        @SharedReader(.smartProtocolConfig) var smartProtocolConfig
        return ProtocolSupport(vpnProtocols: smartProtocolConfig.supportedProtocols)
    case let .vpnProtocol(vpnProtocol):
        return vpnProtocol.protocolSupport
    }
}

public struct ConnectionProtocolSharedKey: SharedKey {
    public static let vpnProtocolKey = "VpnProtocol"
    public static let smartProtocolKey = "smartProtocol"

    public var id: some Hashable {
        "ConnectionProtocolSharedKey"
    }

    public init() {}

    public func load(
        context _: LoadContext<ConnectionProtocol>,
        continuation: LoadContinuation<ConnectionProtocol>
    ) {
        @Dependency(\.defaultAppStorage) var store
        continuation.resume(returning: Self.read(from: store))
    }

    public func subscribe(
        context _: LoadContext<ConnectionProtocol>,
        subscriber: SharedSubscriber<ConnectionProtocol>
    ) -> SharedSubscription {
        @Dependency(\.defaultAppStorage) var store
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            subscriber.yield(Self.read(from: store))
        }
        return SharedSubscription {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func save(
        _ value: ConnectionProtocol,
        context _: SaveContext,
        continuation: SaveContinuation
    ) {
        @Dependency(\.defaultAppStorage) var store
        Self.write(value, to: store)
        continuation.resume()
    }

    // MARK: Storage encoding (matches the legacy PropertiesManager representation)

    public static func read(from store: UserDefaults) -> ConnectionProtocol {
        let smartProtocol = store.object(forKey: smartProtocolKey) != nil
            ? store.bool(forKey: smartProtocolKey)
            : ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault

        guard !smartProtocol else { return .smartProtocol }

        let vpnProtocol = store.data(forKey: vpnProtocolKey)
            .flatMap { try? JSONDecoder().decode(VpnProtocol.self, from: $0) }
            ?? VpnProtocol()
        return .vpnProtocol(vpnProtocol)
    }

    static func write(_ value: ConnectionProtocol, to store: UserDefaults) {
        switch value {
        case .smartProtocol:
            store.set(true, forKey: smartProtocolKey)
        case let .vpnProtocol(vpnProtocol):
            store.set(false, forKey: smartProtocolKey)
            if let data = try? JSONEncoder().encode(vpnProtocol) {
                store.set(data, forKey: vpnProtocolKey)
            }
        }
    }
}
