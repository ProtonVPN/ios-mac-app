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

import Foundation
import Modals_macOS
import vpncore
import AppKit
import VPNShared

class NetshieldDropdownPresenter: QuickSettingDropdownPresenter {
    
    typealias Factory = VpnGatewayFactory & NetShieldPropertyProviderFactory & AppStateManagerFactory & VpnManagerFactory & VpnStateConfigurationFactory & CoreAlertServiceFactory
    
    private let factory: Factory
    
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()

    private var netShieldStats: NetShieldStats?
    private var notificationTokens: [NotificationToken] = []
    
    override var title: String! {
        return LocalizedString.netshieldTitle
    }
    
    override var learnLink: String {
        return CoreAppConstants.ProtonVpnLinks.netshieldSupport
    }

    override var alert: UpsellAlert {
        NetShieldUpsellAlert()
    }
    
    init( _ factory: Factory ) {
        self.factory = factory
        super.init( factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager(), alertService: factory.makeCoreAlertService())
        netShieldStats = vpnManager.netShieldStats // initial value before receiving a new value in a notification

        notificationTokens.append(NotificationCenter.default.addObserver(for: NetShieldStatsNotification.self, object: nil) { [weak self] stats in
            self?.netShieldStats = stats
            self?.contentChanged()
        })
    }

    deinit {
        notificationTokens = []
    }

    var netShieldViewModel: vpncore.NetShieldStatsViewModel {
        // Show grayed out stats if disconnected, or netshield is turned off
        let isActive = appStateManager.displayState == .connected && netShieldPropertyProvider.netShieldType == .level2

        let stats = netShieldStats ?? .zero

        return .enabled(
            adsBlocked: stats.adsBlocked,
            trackersStopped: stats.trackersBlocked,
            bytesSaved: stats.bytesSaved,
            paused: !isActive
        )
    }
    
    override var options: [QuickSettingsDropdownOptionPresenter] {
        return [NetShieldType.off, NetShieldType.level1, NetShieldType.level2].map({ self.createNetshieldOption(level: $0) })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownUpgradeButton.isHidden = true
        viewController?.dropdownDescription.attributedStringValue = LocalizedString.quickSettingsNetShieldDescription.styled(font: .themeFont(.small), alignment: .left)
        viewController?.dropdownNote.attributedStringValue = LocalizedString.quickSettingsNetShieldNote.styled(.weak, font: .themeFont(.small, italic: true), alignment: .left)
    }

    private func contentChanged() {
        viewController?.updateNetshieldStats()
    }
    
    // MARK: - Private

    private func createNetshieldOption(level: NetShieldType) -> QuickSettingGenericOption {
        return QuickSettingNetshieldOption(level: level, vpnGateway: vpnGateway, vpnManager: vpnManager, netShieldPropertyProvider: netShieldPropertyProvider, vpnStateConfiguration: vpnStateConfiguration, isActive: netShieldPropertyProvider.netShieldType == level, currentUserTier: currentUserTier, openUpgradeLink: presentUpsellAlert)
    }
    
    private var currentUserTier: Int {
        return(try? vpnGateway.userTier()) ?? CoreAppConstants.VpnTiers.free
    }
}
