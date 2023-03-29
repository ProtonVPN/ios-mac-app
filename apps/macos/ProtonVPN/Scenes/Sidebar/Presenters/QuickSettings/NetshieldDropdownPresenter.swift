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
    }

    override var statsModel: NetShieldStatsViewModel? {
        let isActive = appStateManager.displayState == .connected && netShieldPropertyProvider.netShieldType == .level2
        return .init(adsStats: .init(value: "21",
                              title: "Ads\nblocked",
                              help: "Advertisement websites use cookies and trackers to target you.",
                              isDisabled: !isActive),
              trackersStats: .init(value: "14",
                                   title: "Trackers\nstopped",
                                   help: "Trackers are third-party websites that collect, store, and sell information about your web activity.",
                                   isDisabled: !isActive),
              dataStats: .init(value: "1.5 MB",
                               title: "Data\nsaved",
                               help: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                               isDisabled: !isActive))
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
    
    // MARK: - Private

    private func createNetshieldOption(level: NetShieldType) -> QuickSettingGenericOption {
        return QuickSettingNetshieldOption(level: level, vpnGateway: vpnGateway, vpnManager: vpnManager, netShieldPropertyProvider: netShieldPropertyProvider, vpnStateConfiguration: vpnStateConfiguration, isActive: netShieldPropertyProvider.netShieldType == level, currentUserTier: currentUserTier, openUpgradeLink: presentUpsellAlert)
    }
    
    private var currentUserTier: Int {
        return(try? vpnGateway.userTier()) ?? CoreAppConstants.VpnTiers.free
    }
}
