//
//  Created on 07/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Ergonomics
import Foundation
import LegacyCommon
import Modals
import ProtonCorePaymentsV2
import StoreKit
import VPNAppCore

@testable import ProtonVPN

class PlanServiceMockV2: PlanServiceV2 {
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

    func purchase(_: Product) async throws -> ComposedPlan {
        throw GenericError(message: "Just error")
    }

    func fetchAppleStatus() async throws {}
    func clear() {}
}
