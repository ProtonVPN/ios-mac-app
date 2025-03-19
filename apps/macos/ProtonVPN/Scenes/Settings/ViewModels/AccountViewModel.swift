//
//  AccountViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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

import Dependencies

import LegacyCommon
import VPNShared
import VPNAppCore
import CommonNetworking

import Strings
import Ergonomics

final class AccountViewModel {
    
    private(set) var username: String
    private(set) var planTitle: String?
    private(set) var maxTier: Int


    private let vpnKeychain: VpnKeychainProtocol
    private let propertiesManager: PropertiesManagerProtocol
    private let authKeychain: AuthKeychainHandle

    var reloadNeeded: (() -> Void)?
    
    init(vpnKeychain: VpnKeychainProtocol,
         propertiesManager: PropertiesManagerProtocol,
         authKeychain: AuthKeychainHandle) {
        self.vpnKeychain = vpnKeychain
        self.propertiesManager = propertiesManager
        self.authKeychain = authKeychain

        username = Localizable.unavailable
        planTitle = nil
        maxTier = .freeTier

        reload()
    }
    
    func manageSubscriptionAction() {
        Task {
            @Dependency(\.sessionService) var sessionService
            let url = await sessionService.getPlanSession(mode: .manageSubscription)
            SafariService.openLink(url: url)
        }
    }

    func reload() {
        if let username = authKeychain.username {
            self.username = username
            do {
                let vpnCredentials = try vpnKeychain.fetchCached()
                planTitle = vpnCredentials.planTitle
                maxTier = vpnCredentials.maxTier
            } catch {
                planTitle = nil
                maxTier = .freeTier
            }
        } else {
            username = Localizable.unavailable
            planTitle = nil
            maxTier = .freeTier
        }

        reloadNeeded?()
    }
}
