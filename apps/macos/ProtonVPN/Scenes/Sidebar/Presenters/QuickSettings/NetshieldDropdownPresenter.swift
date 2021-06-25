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
import vpncore
import AppKit

class NetshieldDropdownPresenter: QuickSettingDropdownPresenter {
    
    typealias Factory = VpnGatewayFactory & NetShieldPropertyProviderFactory & AppStateManagerFactory & VpnManagerFactory
    
    private let factory: Factory
    
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    
    override var title: String! {
        return LocalizedString.netshieldTitle
    }
    
    override var learnLink: String {
        return CoreAppConstants.ProtonVpnLinks.netshieldSupport
    }
    
    init( _ factory: Factory ) {
        self.factory = factory
        super.init( factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager() )
    }
    
    override var options: [QuickSettingsDropdownOptionPresenter] {
        return [NetShieldType.off, NetShieldType.level1, NetShieldType.level2].map({ self.createNetshieldOption(level: $0) })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownUgradeButton.isHidden = true
        viewController?.dropdownDescription.attributedStringValue = LocalizedString.quickSettingsNetShieldDescription.attributed(withColor: .protonWhite(), fontSize: 12, alignment: .left)
        viewController?.dropdownNote.attributedStringValue = LocalizedString.quickSettingsNetShieldNote.attributed(withColor: .protonGreyUnselectedWhite(), fontSize: 12, italic: true, alignment: .left)
    }
    
    // MARK: - Private

    private func createNetshieldOption(level: NetShieldType) -> QuickSettingGenericOption {
        return QuickSettingNetshieldOption(level: level, vpnGateway: vpnGateway, vpnManager: vpnManager, netShieldPropertyProvider: netShieldPropertyProvider, isActive: netShieldPropertyProvider.netShieldType == level, currentUserTier: currentUserTier, openUpgradeLink: openUpgradeLink)
    }
    
    private var currentUserTier: Int {
        return(try? vpnGateway.userTier()) ?? CoreAppConstants.VpnTiers.free
    }
    
}
