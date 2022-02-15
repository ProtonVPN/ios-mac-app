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
import UIKit

class Upsell {
    
    private let planService: PlanService
    private let factory = ModalsFactory(colors: UpsellColors())
    
    private weak var presentedUpsellViewController: UIViewController?
    
    init(planService: PlanService) {
        self.planService = planService
    }
    
    func presentAllCountriesUpsell() {
        let upsellViewController = factory.upsellViewController(upsellType: .allCountries(UpsellConstants()))
        presentUpsell(upsellViewController)
    }
    
    func presentNetShieldUpsell() {
        let upsellViewController = factory.upsellViewController(upsellType: .netShield)
        presentUpsell(upsellViewController)
    }
    
    func presentSecureCoreUpsell() {
        let upsellViewController = factory.upsellViewController(upsellType: .secureCore)
        presentUpsell(upsellViewController)
    }
    
    func presentSafeModeUpsell() {
        let upsellViewController = factory.upsellViewController(upsellType: .safeMode)
        presentUpsell(upsellViewController)
    }
    
    func presentNATUpsell() {
        let upsellViewController = factory.upsellViewController(upsellType: .moderateNAT)
        presentUpsell(upsellViewController)
    }
    
    private func presentUpsell(_ upsellViewController: UpsellViewController) {
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
