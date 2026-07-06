//
//  Created on 24.02.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Combine
import CommonNetworking
import ComposableArchitecture
import Connection
import Dependencies
import Domain
import ExtensionManager
import Foundation
import LegacyCommon
import Settings
import Sharing
import Strings
import VPNAppCore
import VPNShared

final class AdvancedSettingsViewModel {
    @Dependency(\.coreAlertService) private var alertService
    @Dependency(\.upsellManager) private var upsellManager

    @Dependency(\.featureAuthorizerProvider) private var featureAuthorizerProvider
    @Dependency(\.hermesClient) private var hermesClient
    @Dependency(\.natTypePropertyProvider) private var natTypePropertyProvider
    @Dependency(\.connectionCommandClient) private var connectionCommandClient

    @Shared(.telemetryUsageData) var telemetryUsageData
    @Shared(.telemetryCrashReports) var telemetryCrashReports
    @Shared(.connectionState) private var connectionState: ConnectionState
    @SharedReader(.appliedFeatures) private var appliedFeatures: AgentTunnelFeatures?

    @Shared(.featureFlags) private var featureFlags: FeatureFlags

    var reloadNeeded: (() -> Void)?

    lazy var hermesViewModel = HermesViewModel()

    private var natTypeObserverTask: Task<Void, Never>?
    private var featureFlagsObservation: AnyCancellable?

    init() {
        // Observe feature flags changes via the @Shared(.featureFlags) publisher
        self.featureFlagsObservation = $featureFlags.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.settingsChanged() }

        // Observe NAT type changes via AsyncStream
        self.natTypeObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = natTypePropertyProvider.natTypeStream()
            for await _ in stream {
                try? Task.checkCancellation()
                await MainActor.run {
                    self.settingsChanged()
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        natTypeObserverTask?.cancel()
    }

    var alternativeRouting: Bool {
        @Shared(.alternativeRouting) var alternativeRouting
        return alternativeRouting
    }

    var isNATTypeFeatureEnabled: Bool {
        featureFlags.moderateNAT
    }

    var usageData: Bool {
        get {
            telemetryUsageData == String(true)
        }
        set {
            $telemetryUsageData.withLock { $0 = String(newValue) }
        }
    }

    var crashReports: Bool {
        get {
            telemetryCrashReports == String(true)
        }
        set {
            $telemetryCrashReports.withLock { $0 = String(newValue) }
        }
    }

    var natDisplayState: PaidFeatureDisplayState {
        paidFeatureDisplayState(for: NATFeature.self, isEnabled: natTypePropertyProvider.getNATType() == .moderateNAT)
    }

    /// Only non-nil when the server reports a different value.
    var appliedNATOverride: Bool? {
        guard case .connected = connectionState, let applied = appliedFeatures?.natType else { return nil }
        guard applied != natTypePropertyProvider.getNATType() else { return nil }

        // The toggle is set to "on" when moderate NAT is enabled. Otherwise, a "false" value indicates strict NAT.
        return applied == .moderateNAT
    }

    func displayState(for feature: (some ProvidableFeature & ToggleableFeature & Sendable).Type) -> PaidFeatureDisplayState {
        paidFeatureDisplayState(for: feature)
    }

    // MARK: - Upsell Modals

    func showNATUpsell() {
        upsellManager.present(.moderateNat)
    }

    // MARK: - Setters

    func setNatType(natType: NATType, completion: @escaping ((Bool) -> Void)) {
        let canUseNat = featureAuthorizerProvider.authorizer(for: NATFeature.self)
        let result = canUseNat()
        guard case .success = result else {
            if result.requiresUpgrade {
                upsellManager.present(.moderateNat)
            }
            completion(false)
            return
        }

        switch VpnFeatureChangeState(connectionState: connectionState) {
        case .withConnectionUpdate:
            // in-place change when connected and using local agent
            natTypePropertyProvider.setNATType(natType)
            connectionCommandClient.send(.applySettings([.agent(.moderateNAT(natType))]))
            completion(true)
        case .withReconnect:
            alertService.push(alert: ReconnectOnActionAlert(actionTitle: Localizable.moderateNatTitle, confirmHandler: { [weak self] in
                self?.natTypePropertyProvider.setNATType(natType)
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "natType"])
                self?.connectionCommandClient.send(.retry)
                completion(true)
            }, cancelHandler: {
                completion(false)
            }))
        case .immediate:
            natTypePropertyProvider.setNATType(natType)
            completion(true)
        }
    }

    func setAlternatveRouting(_ enabled: Bool) {
        @Shared(.alternativeRouting) var alternativeRouting
        $alternativeRouting.withLock { $0 = enabled }
    }

    @objc
    private func settingsChanged() {
        reloadNeeded?()
    }
}
