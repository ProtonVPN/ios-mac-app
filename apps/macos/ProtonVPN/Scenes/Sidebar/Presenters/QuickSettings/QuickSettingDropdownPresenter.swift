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
import LegacyCommon

protocol QuickSettingDropdownPresenterProtocol: AnyObject {
    
    var title: String! { get }
    
    var viewController: QuickSettingsDetailViewControllerProtocol? { get set }
    var options: [QuickSettingsDropdownOptionPresenter] { get }
    var dismiss: (() -> Void)? { get set }

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
    let alertService: CoreAlertService
    
    var dismiss: (() -> Void)?
    
    init( _ vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager, alertService: CoreAlertService) {
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.alertService = alertService
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(vpnPlanChanged), name: VpnKeychain.vpnPlanChanged, object: nil)
    }
    
    var options: [QuickSettingsDropdownOptionPresenter] {
        return []
    }
    
    func viewDidLoad() {
        viewController?.dropdownTitle.attributedStringValue = title.styled(font: .themeFont(.heading4), alignment: .left)
        viewController?.dropdownUpgradeButton.target = self
        viewController?.dropdownUpgradeButton.action = #selector(presentUpsellAlert)
        viewController?.dropdownLearnMore.target = self
        viewController?.dropdownLearnMore.action = #selector(didTapLearnMore)
    }
    
    // MARK: - Utils
    
    func displayReconnectionFeedback() {
        guard vpnGateway.connection == .connected else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        guard let countryCode = appStateManager.activeConnection()?.server.countryCode else {
            vpnGateway.quickConnect(trigger: .auto)
            return
        }
        vpnGateway.connectTo(country: countryCode, ofType: .unspecified, trigger: .country)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard self.vpnGateway.connection == .connected else { return }
            self.vpnGateway.quickConnect(trigger: .country)
        }
    }

    @objc private func vpnPlanChanged() {
        viewController?.reloadOptions()
    }
    
    // MARK: - Actions
    
    @objc private func didTapLearnMore() {
        SafariService().open(url: learnLink)
    }

    var alert: UpsellAlert {
        log.assertionFailure("This variable should not be used directly. Please inherit and provide your own implementation of `alert`")
        return UpsellAlert()
    }

    @objc func presentUpsellAlert() {
        alertService.push(alert: alert)
    }

    func presentDiscourageSecureCoreAlert(onDontShowAgain: ((Bool) -> Void)?, onActivate: (() -> Void)?, onDismiss: (() -> Void)?) {
        let alert = DiscourageSecureCoreAlert()
        alert.onDontShowAgain = onDontShowAgain
        alert.onActivate = onActivate
        alert.onLearnMore = didTapLearnMore
        alert.dismiss = onDismiss
        alertService.push(alert: alert)
    }
}
