//
//  NetshieldDropdownPresenter.swift
//  ProtonVPN - Created on 04/11/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import AppKit
import Foundation

import Dependencies

import Domain
import Ergonomics
import LegacyCommon
import Modals
import NetShield
import Strings
import VPNAppCore
import VPNShared

class NetshieldDropdownPresenter: QuickSettingDropdownPresenter {
    typealias Factory = AppStateManagerFactory & CoreAlertServiceFactory & VpnGatewayFactory & VpnManagerFactory & VpnStateConfigurationFactory

    private let factory: Factory

    @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    @Dependency(\.propertiesManager) private var propertiesManager

    public private(set) lazy var isNetShieldStatsEnabled = propertiesManager.featureFlags.netShieldStats
    var netShieldStats: NetShieldModel = .zero(enabled: false)
    private var notificationTokens: [NotificationToken] = []
    private var netShieldObserverTask: Task<Void, Never>?

    override var title: String {
        Localizable.netshieldTitle
    }

    override var learnLink: String {
        VPNLink.netshieldSupport.urlString
    }

    override var alert: UpsellAlert {
        NetShieldUpsellAlert()
    }

    init(_ factory: Factory) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
        self.netShieldStats = vpnManager.netShieldStats // initial value before receiving a new value in a notification

        addNetShieldObservers()
    }

    func addNetShieldObservers() {
        notificationTokens.append(NotificationCenter.default.addObserver(for: NetShieldStatsNotification.self, object: nil) { [weak self] stats in
            DispatchQueue.main.async {
                self?.netShieldStats = stats
                self?.contentChanged()
            }
        })

        // Observe NetShield type changes via AsyncStream
        netShieldObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = netShieldPropertyProvider.netShieldTypeStream()
            for await _ in stream {
                try? Task.checkCancellation()
                await MainActor.run {
                    self.contentChanged()
                }
            }
        }
    }

    deinit {
        netShieldObserverTask?.cancel()
    }

    var netShieldViewModel: NetShieldModel {
        // Show grayed out stats if disconnected, or netshield is turned off
        let isActive = appStateManager.displayState == .connected && netShieldPropertyProvider.getNetShieldType() == .level2
        netShieldStats = netShieldStats.copy(enabled: isActive)
        return netShieldStats
    }

    override var options: [QuickSettingDropdownOptionPresenter] {
        [NetShieldType.off, NetShieldType.level1, NetShieldType.level2].map { self.createNetshieldOption(level: $0) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownUpgradeButton.isHidden = true
        viewController?.dropdownDescription.attributedStringValue = Localizable.quickSettingsNetShieldDescription.styled(font: .themeFont(.small), alignment: .left)
        viewController?.dropdownNote.attributedStringValue = Localizable.quickSettingsNetShieldNote.styled(.weak, font: .themeFont(.small), alignment: .left)

        if VPNFeatureFlagType.portForwarding.enabled {
            // (width - traling - leading) / number of buttons
            let oneButtonWidth = (AppConstants.Windows.sidebarWidth - 18 - 18) / 4
            viewController?.arrowHorizontalConstraint.constant = -(oneButtonWidth / 2)
        } else {
            // nothing, will point at the center
        }
    }

    private func contentChanged() {
        viewController?.updateNetshieldStats()
    }

    // MARK: - Private

    private func createNetshieldOption(level: NetShieldType) -> QuickSettingGenericOption {
        @Dependency(\.credentialsProvider) var credentialsProvider
        _ = credentialsProvider.credentials

        return QuickSettingNetshieldOption(
            level: level,
            vpnGateway: vpnGateway,
            vpnManager: vpnManager,
            vpnStateConfiguration: vpnStateConfiguration,
            isActive: netShieldPropertyProvider.getNetShieldType() == level,
            currentUserTier: credentialsProvider.tier,
            currentPlanName: credentialsProvider.planName,
            onPotentialHermesConflict: { [weak self] confirmHandler in
                let hermesAlert = HermesNotificationType.enableNetShield.systemAlert(confirmHandler)
                self?.alertService.push(alert: hermesAlert)
            },
            openUpgradeLink: presentUpsellAlert
        )
    }
}
