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
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Strings
import VPNAppCore

class QuickSettingDropdownPresenter: NSObject {
    var title: String {
        ""
    }

    var descriptionText: String {
        ""
    }

    var noteText: String {
        ""
    }

    var learnLink: String {
        VPNLink.learnMore.urlString
    }

    let vpnGateway: VpnGatewayProtocol
    let appStateManager: AppStateManager
    let alertService: CoreAlertService

    var dismiss: (() -> Void)?
    @MainActor var onChange: (() -> Void)?

    init(_ vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager, alertService: CoreAlertService) {
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.alertService = alertService
        super.init()

        AppEvent.planChanged.subscribe(self, selector: #selector(vpnPlanChanged))
    }

    var options: [QuickSettingDropdownOption] {
        []
    }

    // MARK: - Utils

    func displayReconnectionFeedback() {
        guard vpnGateway.connection == .connected else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        guard let countryCode = appStateManager.activeConnection()?.server.countryCode else {
            vpnGateway.quickConnect(trigger: .auto)
            return
        }
        vpnGateway.connectTo(serverGroup: .country(code: countryCode), ofType: .unspecified, trigger: .country)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard self.vpnGateway.connection == .connected else { return }
            self.vpnGateway.quickConnect(trigger: .country)
        }
    }

    @objc
    private func vpnPlanChanged() {
        Task { @MainActor in
            onChange?()
        }
    }

    // MARK: - Actions

    func didTapLearnMore() {
        @Dependency(\.linkOpener) var linkOpener
        linkOpener.open(learnLink)
    }

    var alert: UpsellAlert {
        log.assertionFailure("This variable should not be used directly. Please inherit and provide your own implementation of `alert`")
        return UpsellAlert()
    }

    @objc
    func presentUpsellAlert() {
        alertService.push(alert: alert)
    }

    func didTapUpgrade() {
        presentUpsellAlert()
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
