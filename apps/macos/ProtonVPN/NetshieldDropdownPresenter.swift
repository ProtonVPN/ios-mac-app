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

class NetshieldDropdownPresenter: QuickSettingDropdownPresenter {
    
    typealias Factory = VpnGatewayFactory & NetShieldPropertyProviderFactory & AppStateManagerFactory
    
    private let factory: Factory
    
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    
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
        return [netshieldOff, netshieldLevel1, netshieldLevel2]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownUgradeButton.isHidden = true
        viewController?.dropdownDescription.attributedStringValue = LocalizedString.qsNSdescription.attributed(withColor: .protonWhite(), fontSize: 12, alignment: .left)
        viewController?.dropdownNote.attributedStringValue = LocalizedString.qsNSNote.attributed(withColor: .protonGreyUnselectedWhite(), fontSize: 12, italic: true, alignment: .left)
    }
    
    // MARK: - Private
    
    private var netshieldOff: QuickSettingGenericOption {
        let active = netShieldPropertyProvider.netShieldType == .off
        let text = LocalizedString.qsNetshieldOptionOff
        let icon = #imageLiteral(resourceName: "qs_netshield_off")
        return QuickSettingGenericOption(text, icon: icon, selectedColor: .protonWhite(), active: active, selectCallback: {
            self.netShieldPropertyProvider.netShieldType = .off
            if self.vpnGateway.connection == .connected {
                self.vpnGateway.reconnect(with: self.netShieldPropertyProvider.netShieldType)
            }
        })
    }
    
    private var netshieldLevel1: QuickSettingGenericOption {
        let level = NetShieldType.level1
        let active = netShieldPropertyProvider.netShieldType == level
        let text = LocalizedString.qsNetshieldOptionLevel1
        let icon = #imageLiteral(resourceName: "qs_netshield_level1")
        return QuickSettingGenericOption(text, icon: icon, active: active, requiresUpdate: level.isUserTierTooLow(currentUserTier), selectCallback: {
            self.netShieldPropertyProvider.netShieldType = .level1
            if self.vpnGateway.connection == .connected {
                self.vpnGateway.reconnect(with: self.netShieldPropertyProvider.netShieldType)
            }
        })
    }
    
    private var netshieldLevel2: QuickSettingGenericOption {
        let level = NetShieldType.level2
        let active = netShieldPropertyProvider.netShieldType == level
        let text = LocalizedString.qsNetshieldOptionLevel2
        let icon = #imageLiteral(resourceName: "qs_netshield_level2")
        return QuickSettingGenericOption(text, icon: icon, active: active, requiresUpdate: level.isUserTierTooLow(currentUserTier), selectCallback: {
            self.netShieldPropertyProvider.netShieldType = .level2
            if self.vpnGateway.connection == .connected {
                self.vpnGateway.reconnect(with: self.netShieldPropertyProvider.netShieldType)
            }
        })
    }
    
    private var currentUserTier: Int {
        return(try? vpnGateway.userTier()) ?? CoreAppConstants.VpnTiers.free
    }
    
}
