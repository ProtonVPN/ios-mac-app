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

import Combine
import Dependencies
import Domain
import Foundation
import ModalsServices
import ProtonCorePaymentsV2
import StoreKit
import VPNShared

final class PlanService {
    private var cancellables: [AnyCancellable] = []
    private var transactionSubscriptionCancellable: Cancellable?

    @Dependency(\.dohConfiguration) private var doh
    @Dependency(\.authKeychain) private var authKeychain

    private lazy var paymentsAPIs = PaymentsAPIs(doh: doh)
    private var remoteManager: RemoteManagerProviding?
    private var plansComposer: PlansComposerProviding?
    private var protonPlansManager: ProtonPlansManagerProviding?

    var iapSupportStatus: IAPSupportStatusV2 = .disabled(localizedReason: nil)

    var transactionProgress: CurrentValueSubject<TransactionHandlerState, Never> = .init(.idle)

    // MARK: - Init

    init() {
        // initial setup; will create managers if auth credentials are present
        createPaymentsManagers()
        recreateTransactionSubscription()

        // setup subscription to react to auth credentials change
        AppEvent.authCredentialsChanged.publisher
            .sink { [weak self] _ in
                self?.updateRemoteManager()
                self?.recreateTransactionSubscription()
            }
            .store(in: &cancellables)
    }

    private func createPaymentsManagers() {
        guard let authCredentials = authKeychain.fetch() else {
            log.info("No auth credentials to create payment managers", category: .iap)
            return clear()
        }
        let appInfo = AppInfoImplementation(context: .mainApp)

        let remoteManager = RemoteManager(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            atlasSecret: doh.atlasSecret
        )
        self.remoteManager = remoteManager
        let plansComposer = PlansComposer(remoteManager: remoteManager, paymentsAPIs: paymentsAPIs)
        self.plansComposer = plansComposer
        let protonPlansManager = ProtonPlansManager(doh: doh, remoteManager: remoteManager, plansComposer: plansComposer)
        self.protonPlansManager = protonPlansManager
    }

    private func updateRemoteManager() {
        guard remoteManager != nil else {
            return createPaymentsManagers()
        }
        guard let authCredentials = authKeychain.fetch() else {
            log.info("No auth credentials to update payment managers", category: .iap)
            return clear()
        }
        remoteManager?.updateSession(sessionID: authCredentials.sessionId, authToken: authCredentials.accessToken)
    }

    private func recreateTransactionSubscription() {
        guard let authCredentials = authKeychain.fetch() else {
            log.info("No auth credentials to subscribe to transactions", category: .iap)
            return clear()
        }
        // unsubscribe from previous subscriptions
        transactionSubscriptionCancellable = nil

        let appInfo = AppInfoImplementation(context: .mainApp)

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            doh: doh
        )
        TransactionsObserver.shared.setConfiguration(transactionsObserverConfiguration)
        Task {
            do {
                try await TransactionsObserver.shared.start()
            } catch {
                log.warning("Can't start payments transactions observer: \(error)", category: .iap)
            }
        }

        transactionSubscriptionCancellable = protonPlansManager?.transactionProgress
            .sink { [weak self] transactionProgress in
                self?.handleTransactionProgress(transactionProgress)
            }
    }

    func clear() {
        remoteManager = nil
        plansComposer = nil
        protonPlansManager = nil
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()
    }

    func fetchAppleStatus() async throws {
        let iapStatusRequest = try paymentsAPIs.url(for: .appleStatus)
        let iapV6Response: IAPStatus? = try await remoteManager?.getFromURL(iapStatusRequest.url)
        // if no remoteManager is present then we're in incorrect state => iAP disabled
        iapSupportStatus = iapV6Response?.status ?? .disabled(localizedReason: nil)
    }

    private var availablePlans: [ComposedPlan] = []

    @MainActor
    func planOptions() async throws -> [PlanOption] {
        guard let protonPlansManager else {
            throw UnavailableError.noAuthDataPresent
        }
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
        guard let protonPlansManager else {
            throw UnavailableError.noAuthDataPresent
        }
        guard let composedPlan = availablePlans.first(where: { $0.product.id == planOption.id }),
              let planName = composedPlan.plan.name,
              let product = composedPlan.product as? Product else {
            throw PurchaseError.planNotFound("unknown")
        }

        return try await protonPlansManager.purchase(product, planName: planName, planCycle: composedPlan.instance.cycle)
    }

    private func handleTransactionProgress(_ transactionProgress: TransactionHandlerState) {
        self.transactionProgress.send(transactionProgress)
    }
}

extension PlanService {
    enum UnavailableError: Error {
        case noAuthDataPresent
    }

    enum PurchaseError: Error, LocalizedError {
        case ffDisabled
        case planNotFound(String)
    }
}

// MARK: - Dependencies

private enum PlanServiceKey: DependencyKey {
    static let liveValue: PlanService = .init()
}

extension DependencyValues {
    var planService: PlanService {
        get { self[PlanServiceKey.self] }
        set { self[PlanServiceKey.self] = newValue }
    }
}
