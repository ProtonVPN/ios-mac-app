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
import ProtonCorePaymentsV2
import StoreKit
import VPNAppCore

@testable import ProtonVPN

class PlanServiceMock: PlanService {
    weak var delegate: PlanServiceDelegate?

    var mostExpensivePlan: ComposedPlan? { nil }

    var countryCode: String? { nil }

    var iapStatus: IAPSupportStatusV2 { .enabled }

    var callbackPresentSubscriptionManagement: (() -> Void)?

    var countriesCount: Int {
        63
    }

    func setDelegate(_ delegate: PlanServiceDelegate) {
        self.delegate = delegate
    }

    func presentSubscriptionManagement(alertService _: CoreAlertService) {
        callbackPresentSubscriptionManagement?()
    }

    func getAvailablePlans() async throws -> [ComposedPlan] {
        []
    }

    func purchase(_: Product, planName _: String, planCycle _: Int) async throws -> ComposedPlan {
        throw LocalError.justError
    }

    func fetchAppleStatus() async throws {}
    func clear() {}
}

private enum LocalError: Error {
    case justError
}
