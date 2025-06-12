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
    import Dependencies
    import NetworkExtension

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
                let manager = try await makeOrGetManager()
                try manager.connection.startVPNTunnel()
                log.info("Plutonium started")
            },
            stop: {
                updateAppliedConfiguration()
                let manager = try await makeOrGetManager()
                guard manager.connection.status == .connected else { return }
                manager.connection.stopVPNTunnel()
                log.info("Plutonium stopped")
            }
        )

        public static let testValue = PlutoniumManager(
            start: {},
            stop: {}
        )

        private static func makeOrGetManager() async throws -> NETransparentProxyManager {
            // 1. load everything
            let managers = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[NETransparentProxyManager], Error>) in
                NETransparentProxyManager.loadAllFromPreferences { list, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: list ?? []) }
                }
            }

            // 2. find an existing one
            if let existing = managers.firstMatching(bundleId: bundleId) {
                return existing
            }

            // 3. create + save + load a brand-new one
            let newManager = NETransparentProxyManager()
            let config = NETunnelProviderProtocol()
            config.providerBundleIdentifier = bundleId
            config.serverAddress = "127.0.0.1"
            newManager.protocolConfiguration = config
            newManager.localizedDescription = descriptionText
            newManager.isEnabled = true

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                newManager.saveToPreferences { saveError in
                    if let saveError {
                        continuation.resume(throwing: saveError)
                        return
                    }
                    continuation.resume(returning: ())
                }
            }

            return newManager
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
