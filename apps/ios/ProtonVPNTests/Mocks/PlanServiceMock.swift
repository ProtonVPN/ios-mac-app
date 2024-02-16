//
//  PlanServiceMock.swift
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
import Modals
import Modals_iOS
import ProtonCorePayments

@testable import ProtonVPN

class PlanServiceMock: PlanService {
    var plansDataSource: PlansDataSourceProtocol?
    
    var payments: ProtonCorePayments.Payments {
        fatalError()
    }

    weak var delegate: PlanServiceDelegate?
    
    var callbackPresentPlanSelection: (() -> Void)?
    var callbackPresentSubscriptionManagement: (() -> Void)?

    var countriesCount: Int {
        return 63
    }

    var allowUpgrade: Bool {
        return true
    }

    func updateServicePlans() async throws {

    }
    
    func presentPlanSelection(modalSource: LegacyCommon.UpsellEvent.ModalSource?) {
        callbackPresentPlanSelection?()
    }
    
    func presentSubscriptionManagement() {
        callbackPresentSubscriptionManagement?()
    }

    func clear() {

    }

    func createPlusPlanUI(completion: @escaping () -> Void) {
        
    }

    func planOptions(with plansDataSource: ProtonCorePayments.PlansDataSourceProtocol) async throws -> [Modals.PlanOption] {
        []
    }

    func buyPlan(planOption: PlanOption) async -> PurchaseResult {
        .purchaseCancelled
    }
}
