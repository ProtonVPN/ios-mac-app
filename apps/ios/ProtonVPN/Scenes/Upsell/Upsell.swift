//
//  Created on 14/02/2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import Modals
import Modals_iOS
import UIKit
import vpncore

class Upsell {
    
    private let planService: PlanService
    private let factory = ModalsFactory(colors: UpsellColors())
    
    private weak var presentedUpsellViewController: UIViewController?
    
    init(planService: PlanService) {
        self.planService = planService
    }
    
    func presentAllCountriesUpsell() {
        let plus = AccountPlan.plus
        let upsell = UpsellType.allCountries(numberOfDevices: plus.devicesCount, numberOfServers: plus.serversCount, numberOfCountries: plus.countriesCount)
        presentUpsell(upsell)
    }
    
    func presentNetShieldUpsell() {
        presentUpsell(.netShield)
    }
    
    func presentSecureCoreUpsell() {
        presentUpsell(.secureCore)
    }
    
    func presentSafeModeUpsell() {
        presentUpsell(.safeMode)
    }
    
    func presentNATUpsell() {
        presentUpsell(.moderateNAT)
    }
    
    private func presentUpsell(_ upsellType: UpsellType) {
        let upsellViewController = factory.upsellViewController(upsellType: upsellType)
        upsellViewController.delegate = self
        presentedUpsellViewController = upsellViewController
        topViewController()?.present(upsellViewController, animated: true, completion: nil)
    }
    
    private func topViewController() -> UIViewController? {
        var topViewController: UIViewController?
        let keyWindow = UIApplication.getInstance()?.windows.filter { $0.isKeyWindow }.first
        if var top = keyWindow?.rootViewController {
            while let presentedViewController = top.presentedViewController {
                top = presentedViewController
            }
            topViewController = top
        }
        return topViewController
    }
}

extension Upsell: UpsellViewControllerDelegate {
    func userDidRequestPlus() {
        presentedUpsellViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.planService.presentPlanSelection()
        })
    }
    
    func userDidDismissUpsell() {
        presentedUpsellViewController?.dismiss(animated: true, completion: nil)
    }
}
