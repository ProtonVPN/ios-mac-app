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

import CommonNetworking
import ComposableArchitecture
import Connection
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Settings
import Sharing
import Strings
import VPNAppCore
import VPNShared

final class AdvancedSettingsViewModel {
    typealias Factory = CoreAlertServiceFactory
    private let factory: Factory

    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    @Dependency(\.propertiesManager) private var propertiesManager

    @Dependency(\.appFeaturePropertyProvider) private var featurePropertyProvider
    @Dependency(\.featureAuthorizerProvider) private var featureAuthorizerProvider
    @Dependency(\.hermesClient) private var hermesClient
    @Dependency(\.natTypePropertyProvider) private var natTypePropertyProvider
    @Dependency(\.connectionCommandClient) private var connectionCommandClient

    @Shared(.telemetryUsageData) var telemetryUsageData
    @Shared(.telemetryCrashReports) var telemetryCrashReports
    @Shared(.connectionState) private var connectionState: ConnectionState

    private var featureFlags: FeatureFlags {
        propertiesManager.featureFlags
    }

    var reloadNeeded: (() -> Void)?

    lazy var hermesViewModel = HermesViewModel(factory: factory)

    private var natTypeObserverTask: Task<Void, Never>?

    init(factory: Factory) {
        self.factory = factory

        // Observe feature flags changes via NotificationCenter (legacy)
        let events: [AppEvent] = [.featureFlags]
        events.subscribe(self, selector: #selector(settingsChanged))

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
        let canUseNat = featureAuthorizerProvider.authorizer(for: NATFeature.self)
        switch canUseNat() {
        case .success:
            return .available(enabled: natTypePropertyProvider.getNATType() == .moderateNAT, interactive: true)
        case .failure(.featureDisabled):
            return .disabled
        case .failure(.requiresUpgrade):
            return .upsell
        }
    }

    func displayState(for feature: (some ProvidableFeature & ToggleableFeature).Type) -> PaidFeatureDisplayState {
        let authorizer: () -> FeatureAuthorizationResult = featureAuthorizerProvider.authorizer(for: feature)
        switch authorizer() {
        case .success:
            return .available(enabled: featurePropertyProvider.getValue(for: feature) == .on, interactive: true)
        case .failure(.featureDisabled):
            return .disabled
        case .failure(.requiresUpgrade):
            return .upsell
        }
    }

    // MARK: - Upsell Modals

    func showNATUpsell() {
        alertService.push(alert: ModerateNATUpsellAlert())
    }

    // MARK: - Setters

    func setNatType(natType: NATType, completion: @escaping ((Bool) -> Void)) {
        let canUseNat = featureAuthorizerProvider.authorizer(for: NATFeature.self)
        let result = canUseNat()
        guard case .success = result else {
            if result.requiresUpgrade {
                alertService.push(alert: ModerateNATUpsellAlert())
            }
            completion(false)
            return
        }

        switch VpnFeatureChangeState(connectionState: connectionState) {
        case .withConnectionUpdate:
            // in-place change when connected and using local agent
            natTypePropertyProvider.setNATType(natType)
            connectionCommandClient.send(.applySettings([.moderateNAT(natType)]))
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
