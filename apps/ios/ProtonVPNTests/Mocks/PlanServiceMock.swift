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
import ProtonCorePayments
import VPNAppCore

@testable import ProtonVPN

class PlanServiceMock: PlanService {
    var paymentTransactionFinishedStream: AsyncStream<PaymentTransactionFinishedEvent>

    init() {
        let (stream, _) = AsyncStream<PaymentTransactionFinishedEvent>.makeStream()
        self.paymentTransactionFinishedStream = stream
    }

    func sendEvent(_: PaymentTransactionFinishedEvent) {}

    var iapStatus: IAPSupportStatus = .enabled

    var plansDataSource: PlansDataSourceProtocol?

    var payments: ProtonCorePayments.Payments {
        fatalError("Should not invoke payments accessor")
    }

    var callbackPresentSubscriptionManagement: (() -> Void)?

    var countriesCount: Int {
        63
    }

    var allowUpgrade: Bool {
        true
    }

    func updateServicePlans() async throws {}

    func presentSubscriptionManagement() {
        callbackPresentSubscriptionManagement?()
    }

    func clear() {}

    func createPlusPlanUI(completion _: @escaping () -> Void) {}
}
