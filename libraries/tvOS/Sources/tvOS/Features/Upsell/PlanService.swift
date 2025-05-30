//
//  Created on 26/08/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Dependencies
import ModalsServices
import ProtonCorePaymentsV2
import StoreKit
import VPNShared

struct PaymentsFactory {
    var payments: @Sendable () -> PlanService
}

extension PaymentsFactory: DependencyKey {
    static let liveValue = PlanService()
}

extension DependencyValues {
    var paymentsService: PlanService? {
        get { self[PaymentsFactory.self] }
        set { self[PaymentsFactory.self] = newValue }
    }
}

final class PlanService {
    let remoteManager: RemoteManagerProviding
    let paymentsAPIs: PaymentsAPIs
    let plansComposer: PlansComposerProviding
    let protonPlansManager: ProtonPlansManagerProviding
    var iapSupportStatus: IAPSupportStatusV2 = .disabled(localizedReason: nil)

    // MARK: - Init

    init?() {
        @Dependency(\.authKeychain) var authKeychain
        guard let authCredentials = authKeychain.fetch() else {
            return nil
        }

        @Dependency(\.dohConfiguration) var doh
        let appInfo = AppInfoImplementation(context: .mainApp)

        let remoteManager = RemoteManager(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion
        )
        self.remoteManager = remoteManager
        let paymentsAPIs = PaymentsAPIs(doh: doh)
        self.paymentsAPIs = paymentsAPIs
        let plansComposer = PlansComposer(remoteManager: remoteManager, paymentsAPIs: paymentsAPIs)
        self.protonPlansManager = ProtonPlansManager(doh: doh, remoteManager: remoteManager, plansComposer: plansComposer)
        self.plansComposer = plansComposer

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            doh: doh
        )
        TransactionsObserver.shared.setConfiguration(transactionsObserverConfiguration)
        Task {
            try? await TransactionsObserver.shared.start()
        }
    }

    func fetchAppleStatus() async throws {
        let iapStatusRequest = try paymentsAPIs.url(for: .appleStatus)
        let iapV6Response: IAPStatus = try await remoteManager.getFromURL(iapStatusRequest.url)
        iapSupportStatus = iapV6Response.status
    }

    private var availablePlans: [ComposedPlan] = []

    @MainActor
    func planOptions() async throws -> [PlanOption] {
        let composedPlans = try await protonPlansManager.getAvailablePlans()
        let vpn2022 = composedPlans.filter { composedPlan in
            composedPlan.plan.name == "vpn2022"
        }
        availablePlans = vpn2022
        return vpn2022.map {
            PlanOption(
                id: $0.product.id,
                storePricePerMonth: $0.storePricePerMonth,
                amountOfMonths: $0.amountOfMonths,
                durationLabel: $0.durationLabel,
                displayPrice: $0.product.displayPrice,
                pricePerMonth: $0.pricePerMonthLabel
            )
        }
    }

    func buyPlan(planOption: PlanOption) async throws -> ComposedPlan {
        guard let composedPlan = availablePlans.first(where: { $0.product.id == planOption.id }),
              let planName = composedPlan.plan.name,
              let product = composedPlan.product as? Product else {
            throw PurchaseError.planNotFound("unknown")
        }

        return try await protonPlansManager.purchase(product, planName: planName, planCycle: composedPlan.instance.cycle)
    }
}

extension PlanService {
    enum PurchaseError: Error, LocalizedError {
        case ffDisabled
        case planNotFound(String)
    }
}
