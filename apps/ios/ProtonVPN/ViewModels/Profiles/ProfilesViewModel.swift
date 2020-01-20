//
//  ProfilesViewModel.swift
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

import UIKit
import vpncore

class ProfilesViewModel {
    typealias Factory = ProfileService
    
    private let factory: Factory
    private let loginService: LoginService
    private let alertService: AlertService
    private var vpnGateway: VpnGatewayProtocol?
    private var profileManager: ProfileManager?
    private let planService: PlanService
    
    private let sectionTitles = [LocalizedString.recommended, LocalizedString.myProfiles]
        
    private var userTier: Int {
        do {
            if let vpnGateway = vpnGateway {
                return try vpnGateway.userTier()
            } else { // not logged in
                return CoreAppConstants.VpnTiers.visionary
            }
        } catch {
            return CoreAppConstants.VpnTiers.free
        }
    }
    
    init(vpnGateway: VpnGatewayProtocol?, factory: Factory, loginService: LoginService, alertService: AlertService, planService: PlanService) {
        self.vpnGateway = vpnGateway
        self.factory = factory
        self.loginService = loginService
        self.alertService = alertService
        self.planService = planService
        
        if vpnGateway != nil {
            profileManager = ProfileManager.shared
        }
    }
    
    func makeCreateProfileViewController() -> UITableViewController? {
        guard vpnGateway != nil else {
            loginService.presentSignup()
            return nil
        }
        return factory.makeCreateProfileViewController(for: nil)
    }
    
    func makeEditProfileViewController(for index: Int) -> UITableViewController? {
        return factory.makeCreateProfileViewController(for: profileManager?.customProfiles[index])
    }
    
    var headerHeight: CGFloat {
        return UIConstants.headerHeight
    }
    
    var sectionCount: Int {
        return 2
    }
    
    func title(for section: Int) -> String {
        return sectionTitles[section].uppercased()
    }
    
    var cellHeight: CGFloat {
        return UIConstants.cellHeight
    }
    
    func cellCount(for section: Int) -> Int {
        switch section {
        case 0:
            return 2 // fastest and random
        default:
            return profileManager?.customProfiles.count ?? 0
        }
    }
    
    func defaultCellModel(for row: Int) -> DefaultProfileViewModel {
        let serverOffering = row == 0 ? ServerOffering.fastest(nil) : ServerOffering.random(nil)
        return DefaultProfileViewModel(serverOffering: serverOffering, vpnGateway: vpnGateway, loginService: loginService)
    }
    
    func cellModel(for index: Int) -> ProfileItemViewModel? {
        if let profile = profileManager?.customProfiles[index] {
            return ProfileItemViewModel(profile: profile, vpnGateway: vpnGateway, loginService: loginService, alertService: alertService, userTier: userTier, planService: planService)
        }
        return nil
    }
    
    func deleteProfile(for index: Int) {
        if let profile = profileManager?.customProfiles[index],
            let profileManager = profileManager {
                profileManager.deleteProfile(profile)
        }
    }
    
    func reloadData() {
        profileManager?.refreshProfiles()
    }
}
