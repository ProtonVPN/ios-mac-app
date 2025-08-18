//
//  Created on 15/05/2025 by Shahin Katebi.
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

#if os(macOS)

    import ComposableArchitecture
    import CoreConnection
    import Dependencies
    import Hermes
    import NetworkExtension
    import VPNAppCore

    public struct PlutoniumManager: DependencyKey, TestDependencyKey {
        public var start: () async throws -> Void
        public var stop: () async throws -> Void

        private static let bundleId = "ch.protonvpn.mac.Transparent-Proxy"
        private static let descriptionText = "ProtonVPN Plutonium"

        private init(
            start: @escaping () async throws -> Void,
            stop: @escaping () async throws -> Void
        ) {
            self.start = start
            self.stop = stop
        }

        public static let liveValue = PlutoniumManager(
            start: {
                @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
                @Dependency(\.hermesClient) var hermesClient
                let manager = try await getManager(
                    providerConfig: feature
                        .toProviderConfigurationDictionary(dnsServers: hermesClient.currentResolvers.map(\.location))
                )
                try manager.connection.startVPNTunnel()
                log.info("Plutonium started")
            },
            stop: {
                updateAppliedConfiguration()
                let manager = try await getManager()
                guard manager.connection.status == .connected else { return }
                manager.connection.stopVPNTunnel()
                log.info("Plutonium stopped")
            }
        )

        public static let testValue = PlutoniumManager(
            start: {},
            stop: {}
        )

        private static func getManager(providerConfig: [String: Any]? = nil) async throws -> NETransparentProxyManager {
            // 1. load all saved managers
            let managers = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[NETransparentProxyManager], Error>) in
                NETransparentProxyManager.loadAllFromPreferences { list, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: list ?? [])
                    }
                }
            }

            // 2. find or create
            let manager: NETransparentProxyManager
            if let existing = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == bundleId
            }) {
                manager = existing
                if let protocolConfig = manager.protocolConfiguration as? NETunnelProviderProtocol {
                    protocolConfig.providerConfiguration = providerConfig
                    manager.protocolConfiguration = protocolConfig
                }
            } else {
                let newManager = NETransparentProxyManager()
                let protocolConfig = NETunnelProviderProtocol()
                protocolConfig.providerBundleIdentifier = bundleId
                protocolConfig.serverAddress = "127.0.0.1"
                protocolConfig.providerConfiguration = providerConfig
                newManager.protocolConfiguration = protocolConfig
                newManager.localizedDescription = descriptionText
                newManager.isEnabled = true
                manager = newManager
            }

            // 3. save the updated manager
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }

            return manager
        }

        private static func updateAppliedConfiguration() {
            @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
            @Shared(.inclusionActivated) var inclusionActivated: PlutoniumActivated
            @Shared(.exclusionActivated) var exclusionActivated: PlutoniumActivated

            @Shared(.plutoniumFeatureApplied) var featureApplied: PlutoniumFeatureToggle
            @Shared(.inclusionActivatedApplied) var inclusionActivatedApplied: PlutoniumActivated
            @Shared(.exclusionActivatedApplied) var exclusionActivatedApplied: PlutoniumActivated

            $featureApplied.withLock { $0 = feature }
            $inclusionActivatedApplied.withLock { $0 = inclusionActivated }
            $exclusionActivatedApplied.withLock { $0 = exclusionActivated }
        }
    }

    public extension DependencyValues {
        var plutoniumManager: PlutoniumManager {
            get { self[PlutoniumManager.self] }
            set { self[PlutoniumManager.self] = newValue }
        }
    }

    extension Collection where Element: NETransparentProxyManager {
        func firstMatching(bundleId: String) -> NETransparentProxyManager? {
            first {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == bundleId
            }
        }
    }

#endif
