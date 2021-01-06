//
//  QuickSettingDropdownPresenter.swift
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

import Cocoa
import vpncore

protocol QuickSettingDropdownPresenterProtocol: class {
    
    var title: String! { get }
    
    var viewController: QuickSettingsDetailViewControllerProtocol? { get set }
    var options: [QuickSettingsDropdownOptionPresenter] { get }
    
    func viewDidLoad()
    func displayReconnectionFeedback()
}

class QuickSettingDropdownPresenter: NSObject, QuickSettingDropdownPresenterProtocol {

    weak var viewController: QuickSettingsDetailViewControllerProtocol?
    
    var title: String! {
        return ""
    }
    
    var learnLink: String {
        return CoreAppConstants.ProtonVpnLinks.learnMore
    }
    
    let vpnGateway: VpnGatewayProtocol
    let appStateManager: AppStateManager
    
    init( _ vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager ) {
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        super.init()
    }
    
    var options: [QuickSettingsDropdownOptionPresenter] {
        return []
    }
    
    func viewDidLoad() {
        viewController?.dropdownTitle.attributedStringValue = title.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        viewController?.dropdownUgradeButton.target = self
        viewController?.dropdownUgradeButton.action = #selector(openUpgradeLink)
        viewController?.dropdownLearnMore.target = self
        viewController?.dropdownLearnMore.action = #selector(didTapLearnMore)
    }
    
    // MARK: - Utils
    
    func displayReconnectionFeedback() {
        guard vpnGateway.connection == .connected else { return }
        guard let countryCode = appStateManager.activeConnection()?.server.countryCode else {
            vpnGateway.quickConnect()
            return
        }
        vpnGateway.connectTo(country: countryCode, ofType: .unspecified)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard self.vpnGateway.connection == .connected else { return }
            self.vpnGateway.quickConnect()
        }
    }
    
    // MARK: - Actions
    
    @objc private func didTapLearnMore() {
        SafariService.openLink(url: learnLink )
    }
    
    // MARK: - Private
    
    @objc private func openUpgradeLink() {
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.upgrade )
    }
}
