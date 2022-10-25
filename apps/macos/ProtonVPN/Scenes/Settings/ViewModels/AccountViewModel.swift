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
import vpncore
import VPNShared

final class AccountViewModel {
    
    private(set) var username: String
    private(set) var accountType: String
    private(set) var accountPlan: AccountPlan?

    var canUsePromo: Bool {
        return propertiesManager.featureFlags.promoCode && (try? vpnKeychain.fetchCached())?.canUsePromoCode ?? false
    }

    private let vpnKeychain: VpnKeychainProtocol
    private let propertiesManager: PropertiesManagerProtocol
    private let sessionService: SessionService
    private let authKeychain: AuthKeychainHandle

    var reloadNeeded: (() -> Void)?
    
    init(vpnKeychain: VpnKeychainProtocol,
         propertiesManager: PropertiesManagerProtocol,
         sessionService: SessionService,
         authKeychain: AuthKeychainHandle) {
        self.vpnKeychain = vpnKeychain
        self.propertiesManager = propertiesManager
        self.sessionService = sessionService
        self.authKeychain = authKeychain

        username = LocalizedString.unavailable
        accountType = LocalizedString.unavailable
        accountPlan = nil

        reload()
    }
    
    func manageSubscriptionAction() {
        Task {
            let url = await sessionService.getPlanSession(mode: .manageSubscription)
            SafariService.openLink(url: url)
        }
    }

    func reload() {
        if let authCredentials = authKeychain.fetch() {
            username = authCredentials.username
            do {
                let vpnCredentials = try vpnKeychain.fetchCached()
                accountType = vpnCredentials.serviceName
                accountPlan = vpnCredentials.accountPlan
            } catch {
                accountType = LocalizedString.unavailable
                accountPlan = nil
            }
        } else {
            username = LocalizedString.unavailable
            accountType = LocalizedString.unavailable
            accountPlan = nil
        }

        reloadNeeded?()
    }
}
