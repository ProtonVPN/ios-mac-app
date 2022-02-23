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

    typealias Factory = PlanServiceFactory
    private let factory: Factory

    private lazy var planService: PlanService = factory.makePlanService()
    private let modalsFactory = ModalsFactory(colors: UpsellColors())

    init(_ factory: Factory) {
        self.factory = factory
    }
    
    func allCountriesUpsell() -> UIViewController {
        let plus = AccountPlan.plus
        let allCountriesUpsell = UpsellType.allCountries(numberOfDevices: plus.devicesCount, numberOfServers: plus.serversCount, numberOfCountries: plus.countriesCount)
        return upsell(allCountriesUpsell)
    }
    
    func netShieldUpsell() -> UIViewController {
        return upsell(.netShield)
    }
    
    func secureCoreUpsell() -> UIViewController {
        return upsell(.secureCore)
    }
    
    func safeModeUpsell() -> UIViewController {
        return upsell(.safeMode)
    }
    
    func natUpsell() -> UIViewController {
        return upsell(.moderateNAT)
    }
    
    private func upsell(_ upsellType: UpsellType) -> UIViewController {
        let upsellViewController = modalsFactory.upsellViewController(upsellType: upsellType)
        upsellViewController.delegate = self
        return upsellViewController
    }
}

extension Upsell: UpsellViewControllerDelegate {
    func userDidRequestPlus() {
        planService.presentPlanSelection()
    }
    
    func userDidDismissUpsell() { }
}
