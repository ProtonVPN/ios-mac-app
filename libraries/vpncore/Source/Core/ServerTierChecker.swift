//
//  ServerTierChecker.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

class ServerTierChecker {
    
    public weak var alertService: CoreAlertService?
    
    private let vpnKeychain: VpnKeychainProtocol
    
    init(alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol) {
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
    }
    
    func serverRequiresUpgrade(_ server: ServerModel) -> Bool? {
        do {
            let userTier = try self.userTier()
            if server.tier > userTier {
                notifyResolutionUnavailable(forSpecificCountry: false, type: server.serverType, reason: .upgrade(server.tier))
                return true
            } else {
                return false
            }
        } catch {
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
            return false
        }
    }
    
    func notifyResolutionUnavailable(forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason) {
        DispatchQueue.main.async { [weak self] in
            switch reason {
            case .upgrade(let tier):
                self?.alertService?.push(alert: UpgradeRequiredAlert(tier: tier, serverType: type, forSpecificCountry: forSpecificCountry, confirmHandler: nil))
            case .existingConnection:
                self?.alertService?.push(alert: ExistingConnectionAlert())
            case .maintenance:
                self?.alertService?.push(alert: MaintenanceAlert(forSpecificCountry: forSpecificCountry))
            }
        }
    }
    
    private func userTier() throws -> Int {
        let tier = try vpnKeychain.fetch().maxTier
        return tier
    }
}
