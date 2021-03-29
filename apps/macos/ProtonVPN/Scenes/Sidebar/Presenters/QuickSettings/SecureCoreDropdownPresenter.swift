//
//  SecureCoreDropdownPresenter.swift
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

class SecureCoreDropdownPresenter: QuickSettingDropdownPresenter {
    
    typealias Factory = VpnGatewayFactory & PropertiesManagerFactory & AppStateManagerFactory
    
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    override var title: String! {
        return LocalizedString.secureCore
    }
    
    override var learnLink: String {
        return CoreAppConstants.ProtonVpnLinks.learnMore
    }
    
    init( _ factory: Factory ) {
        self.factory = factory
        super.init(factory.makeVpnGateway(), appStateManager: factory.makeAppStateManager())
    }
    
    override var options: [QuickSettingsDropdownOptionPresenter] {
        return [self.secureCoreOff, self.secureCoreOn]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewController?.dropdownDescription.attributedStringValue = LocalizedString.qsSCdescription.attributed(withColor: .protonWhite(), fontSize: 12, alignment: .left)
        viewController?.dropdownNote.attributedStringValue = LocalizedString.qsSCNote.attributed(withColor: .protonGreyUnselectedWhite(), fontSize: 12, italic: true, alignment: .left)
        if propertiesManager.featureFlags.isNetShield {
            viewController?.arrowHorizontalConstraint.constant = -((AppConstants.Windows.sidebarWidth - 18) / 3) + 7
        } else {
            viewController?.arrowHorizontalConstraint.constant = -((AppConstants.Windows.sidebarWidth - 18) / 5) - 12
        }
    }
    
    // MARK: - Private
    
    private var secureCoreOff: QuickSettingGenericOption {
        let active = !propertiesManager.secureCoreToggle
        let text = LocalizedString.secureCore + " " + LocalizedString.off.capitalized
        let icon = #imageLiteral(resourceName: "qs_securecore_off")
        return QuickSettingGenericOption(text, icon: icon, selectedColor: .protonWhite(), active: active, requiresUpdate: requiresUpdate(secureCore: false), selectCallback: {
            self.vpnGateway.changeActiveServerType(.standard)
            self.displayReconnectionFeedback()
        })
    }
    
    private var secureCoreOn: QuickSettingGenericOption {
        let active = propertiesManager.secureCoreToggle
        let text = LocalizedString.secureCore + " " + LocalizedString.on.capitalized
        let icon = #imageLiteral(resourceName: "qs_securecore_on")
        return QuickSettingGenericOption(text, icon: icon, active: active, requiresUpdate: requiresUpdate(secureCore: true), selectCallback: {
            guard !self.requiresUpdate(secureCore: true) else {
                self.openUpgradeLink()
                return
            }
            self.vpnGateway.changeActiveServerType(.secureCore)
            self.displayReconnectionFeedback()
        })
    }
    
    private func requiresUpdate(secureCore isOn: Bool) -> Bool {
        return isOn
            ? currentUserTier < CoreAppConstants.VpnTiers.visionary
            : false
    }
    
    private var currentUserTier: Int {
        return(try? vpnGateway.userTier()) ?? CoreAppConstants.VpnTiers.free
    }
}
