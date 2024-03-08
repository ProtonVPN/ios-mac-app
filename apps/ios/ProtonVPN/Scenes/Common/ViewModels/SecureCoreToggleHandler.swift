//
//  SecureCoreToggleHandler.swift
//  ProtonVPN - Created on 01.07.19.
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
import LegacyCommon

protocol SecureCoreToggleHandler: AnyObject {

    var alertService: AlertService { get }
    var propertiesManager: PropertiesManagerProtocol { get }
    var vpnGateway: VpnGatewayProtocol { get }
    var activeView: ServerType { get }

    func toggleState(toOn: Bool, completion: @escaping (Bool) -> Void)
    func setStateOf(type: ServerType)
}

extension SecureCoreToggleHandler {
    private func completionWrapper(succeeded: Bool, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            if succeeded {
                let newType = self.activeView == .secureCore ? ServerType.standard : .secureCore
                self.vpnGateway.changeActiveServerType(newType)
                // Some classes wait for `VpnGateway.activeServerTypeChanged` notification, which is
                // posted on main queue. So to prevent race condition it's better to run `setStateOf`
                // on the same queue.
                DispatchQueue.main.async {
                    self.setStateOf(type: newType)
                }
            }
            completion(succeeded)
        }
    }

    private func checkPlanAndConnection() -> (insufficientPlan: Bool, isNotConnectedToVPN: Bool)? {
        var userTier = 0
        do {
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = .paidTier // not logged in
        }
        let insufficientPlan = activeView == .standard && userTier.isFreeTier
        let isNotConnectedToVPN = vpnGateway.connection != .connected
        return (insufficientPlan, isNotConnectedToVPN)
    }

    private func showDisconnectAlert(completion: @escaping (Bool) -> Void) {
        let disconnectCompletion = { [weak self] in
            self?.completionWrapper(succeeded: true, completion: completion)
            log.debug("Disconnect requested after changing SecureCore", category: .connectionDisconnect, event: .trigger)
            self?.vpnGateway.disconnect()
        }
        alertService.push(alert: SecureCoreToggleDisconnectAlert(confirmHandler: { disconnectCompletion() }, cancelHandler: { [weak self] in self?.completionWrapper(succeeded: false, completion: completion) }))
    }

    private func showDiscourageSecureCoreAlert(isNotConnectedToVPN: Bool, completion: @escaping (Bool) -> Void) {
        let alert = DiscourageSecureCoreAlert()
        alert.onDontShowAgain = { [weak self] dontShowAgain in
            self?.propertiesManager.discourageSecureCore = !dontShowAgain
        }
        alert.onActivate = { [weak self] in
            if isNotConnectedToVPN {
                self?.completionWrapper(succeeded: true, completion: completion)
            } else {
                self?.showDisconnectAlert(completion: completion)
            }
        }
        alert.dismiss = { [weak self] in
            self?.completionWrapper(succeeded: false, completion: completion)
        }
        alertService.push(alert: alert)
    }

    internal func toggleState(toOn: Bool, completion: @escaping (Bool) -> Void) {
        guard let (insufficientPlan, isNotConnectedToVPN) = checkPlanAndConnection() else {
            completionWrapper(succeeded: true, completion: completion)
            return
        }
        guard !insufficientPlan else {
            completionWrapper(succeeded: false, completion: completion)
            alertService.push(alert: SecureCoreUpsellAlert())
            return
        }
        if propertiesManager.discourageSecureCore && toOn {
            showDiscourageSecureCoreAlert(isNotConnectedToVPN: isNotConnectedToVPN, completion: completion)
        } else if isNotConnectedToVPN {
            completionWrapper(succeeded: true, completion: completion)
        } else {
            showDisconnectAlert(completion: completion)
        }
    }
}
