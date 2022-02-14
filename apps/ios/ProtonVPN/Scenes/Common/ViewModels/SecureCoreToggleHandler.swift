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
import vpncore

protocol SecureCoreToggleHandler: AnyObject {
    
    var upsell: Upsell { get }
    
    var alertService: AlertService { get }
    var vpnGateway: VpnGatewayProtocol? { get }
    var activeView: ServerType { get }
    
    func toggleState(completion: @escaping (Bool) -> Void)
    func setStateOf(type: ServerType)
}

extension SecureCoreToggleHandler {
    
    internal func toggleState(completion: @escaping (Bool) -> Void) {
        let completionWrapper: ((Bool) -> Void) = { [weak self] succeeded in
            DispatchQueue.global(qos: .background).async {
                if succeeded {
                    guard let `self` = self else { return }
                    let newType = self.activeView == .secureCore ? ServerType.standard : .secureCore
                    self.vpnGateway?.changeActiveServerType(newType)
                    self.setStateOf(type: newType)
                }
                
                completion(succeeded)
            }
        }
        
        let disconnectCompletion = { [weak self] in
            completionWrapper(true)
            log.debug("Disconnect requested after changing SecureCore", category: .connectionDisconnect, event: .trigger)
            self?.vpnGateway?.disconnect()
        }
        
        guard let vpnGateway = vpnGateway else {
            completionWrapper(true)
            return
        }
        
        var userTier = 0
        do {
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = CoreAppConstants.VpnTiers.plus // not logged in
        }
        if activeView == .standard && userTier < CoreAppConstants.VpnTiers.plus {
            completionWrapper(false)
            upsell.presentSecureCoreUpsell()
        } else if vpnGateway.connection != .connected {
            completionWrapper(true)
        } else {
            alertService.push(alert: SecureCoreToggleDisconnectAlert(confirmHandler: { disconnectCompletion() }, cancelHandler: { completionWrapper(false) }))
        }
    }
}
