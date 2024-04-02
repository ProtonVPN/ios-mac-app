//
//  PlanService.swift
//  vpncore - Created on 01.09.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCoreDataModel
import ProtonCorePayments
import ProtonCorePaymentsUI
import LegacyCommon
import UIKit
import VPNShared
import Modals

protocol PlanServiceFactory {
    func makePlanService() -> PlanService
}

protocol PlanServiceDelegate: AnyObject {
    @MainActor
    func paymentTransactionDidFinish(modalSource: UpsellEvent.ModalSource?, newPlanName: String?) async
}

protocol PlanService {
    var allowUpgrade: Bool { get }
    var countriesCount: Int { get }
    var delegate: PlanServiceDelegate? { get set }
    var plansDataSource: PlansDataSourceProtocol? { get }

    func presentPlanSelection(modalSource: UpsellEvent.ModalSource?)
    func presentSubscriptionManagement()
    func updateServicePlans() async throws
    func createPlusPlanUI(completion: @escaping () -> Void)
    func planOptions(with plansDataSource: PlansDataSourceProtocol) async throws -> [PlanOption]
    func buyPlan(planOption: PlanOption) async -> PurchaseResult

    func clear()
}

extension PlanService {
    func presentPlanSelection() {
        presentPlanSelection(modalSource: nil)
    }
}

final class CorePlanService: PlanService {
    private var paymentsUI: PaymentsUI?
    private let payments: Payments
    private let alertService: CoreAlertService
    private let authKeychain: AuthKeychainHandle
    private let userCachedStatus: UserCachedStatus

    var countriesCount: Int = AccountPlan.plus.countriesCount

    let tokenStorage: PaymentTokenStorage?

    weak var delegate: PlanServiceDelegate?

    var allowUpgrade: Bool {
        return userCachedStatus.paymentsBackendStatusAcceptsIAP
    }

    public typealias Factory = NetworkingFactory &
        CoreAlertServiceFactory &
        AuthKeychainHandleFactory

    public convenience init(_ factory: Factory) {
        self.init(networking: factory.makeNetworking(),
                  alertService: factory.makeCoreAlertService(),
                  authKeychain: factory.makeAuthKeychainHandle())
    }

    init(networking: Networking, alertService: CoreAlertService, authKeychain: AuthKeychainHandle) {
        self.alertService = alertService
        self.authKeychain = authKeychain

        tokenStorage = TokenStorage()
        userCachedStatus = UserCachedStatus()
        payments = Payments(
            inAppPurchaseIdentifiers: ObfuscatedConstants.vpnIAPIdentifiers,
            apiService: networking.apiService,
            localStorage: userCachedStatus,
            reportBugAlertHandler: { receipt in
                log.error("Error from payments, showing bug report", category: .iap)
                alertService.push(alert: ReportBugAlert())
            }
        )

        updateCountriesCount { [weak self] result in
            switch result {
            case .success(let count):
                self?.countriesCount = count
            case .failure:
                self?.countriesCount = AccountPlan.plus.countriesCount
            }
        }
    }
    
    var inAppPurchasePlans: [(PlanOption, InAppPurchasePlan)] = []

    func planOptions(with plansDataSource: PlansDataSourceProtocol) async throws -> [PlanOption] {
        try await plansDataSource.fetchAvailablePlans()
        let vpn2022 = plansDataSource.availablePlans?.plans.filter { plan in
            plan.name == "vpn2022"
        }.first // it's only going to be one with this plan name
        guard let vpn2022 else { throw "Default plan not found" }
        inAppPurchasePlans = vpn2022.instances
            .compactMap { InAppPurchasePlan(availablePlanInstance: $0) }
            .compactMap { iAP -> (PlanOption, InAppPurchasePlan)? in
                guard let priceLabel = iAP.priceLabel(from: payments.storeKitManager),
                      let period = iAP.period else { return nil }
                let planOption = PlanOption(duration: .init(components: .init(month: Int(period))),
                                            price: .init(amount: priceLabel.value.doubleValue,
                                                         currency: iAP.currency ?? "",
                                                         locale: priceLabel.locale))
                return (planOption, iAP)
            }
        return inAppPurchasePlans.map { $0.0 }
    }

    func buyPlan(planOption: PlanOption) async -> PurchaseResult {
        guard !payments.storeKitManager.hasUnfinishedPurchase() else {
            log.debug("StoreKitManager is not ready to purchase", category: .userPlan)
            return .purchaseError(error: "StoreKitManager is not ready to purchase", processingPlan: nil)
        }
        let plan = inAppPurchasePlans.first { plan, _ in
            plan.fingerprint == planOption.fingerprint
        }
        guard let iAP = plan?.1 else {
            return .purchaseError(error: "StoreKitManager plan not found", processingPlan: nil)
        }
        return await withCheckedContinuation {
            payments.purchaseManager.buyPlan(plan: iAP,
                                             finishCallback: $0.resume(returning:))
        }
    }

    private func updateCountriesCount(completion: @escaping (Result<Int, Error>) -> Void) {
        guard case .left(let planService) = payments.planService else { return }
        if let counts = planService.countriesCount {
            return completion(.success(counts.maxCountries()))
        }
        planService.updateCountriesCount {
            if let count = planService.countriesCount?.maxCountries() {
                return completion(.success(count))
            }
            return completion(.failure(CountriesCountError.internalError))
        } failure: { error in
            return completion(.failure(error))
        }
    }

    private enum CountriesCountError: Error {
        case internalError
    }

    var plansDataSource: PlansDataSourceProtocol? {
        guard case .right(let plansDataSource) = payments.planService else {
            return nil
        }
        return plansDataSource
    }

    func updateServicePlans() async throws {
        try await withCheckedThrowingContinuation { continuation in
            payments.activate(delegate: self) { [weak self] _ in
                self?.payments.updateService(completion: continuation.resume(with: ))
            }
        }
    }

    func presentPlanSelection(modalSource: UpsellEvent.ModalSource?) {
        guard userCachedStatus.paymentsBackendStatusAcceptsIAP else {
            alertService.push(alert: UpgradeUnavailableAlert())
            return
        }

        paymentsUI = createPaymentsUI()
        paymentsUI?.showCurrentPlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true) { [weak self] response in
            self?.handlePaymentsResponse(response: response, modalSource: modalSource)
        }
    }

    func presentSubscriptionManagement() {
        paymentsUI = createPaymentsUI()
        paymentsUI?.showCurrentPlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true) { [weak self] response in
            self?.handlePaymentsResponse(response: response, modalSource: nil)
        }
    }

    func createPlusPlanUI(completion: @escaping () -> Void) {
        paymentsUI = createPaymentsUI(onlyPlusPlan: true)
        paymentsUI?.showUpgradePlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true) { [weak self] response in
            switch response {
            case let .purchasedPlan(accountPlan: plan):
                log.debug("Purchased plan: \(plan.protonName)", category: .iap)
                completion()
                Task { [weak self] in
                    await self?.delegate?.paymentTransactionDidFinish(modalSource: nil, newPlanName: plan.protonName)
                }
            case let .purchaseError(error: error):
                log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            case .close:
                log.debug("Payments closed", category: .iap)
            case let .planPurchaseProcessingInProgress(accountPlan: plan):
                log.debug("Purchasing \(plan.protonName)", category: .iap)
            case .toppedUpCredits:
                log.debug("Credits topped up", category: .iap)
            case let .apiMightBeBlocked(message, error):
               log.error("\(message)", category: .connection, metadata: ["error": "\(error)"])
            case .open:
                log.debug("Purchase screen opened", category: .iap)
            }
        }
    }

    func clear() {
        tokenStorage?.clear()
        userCachedStatus.clear()
    }

    private func createPaymentsUI(onlyPlusPlan: Bool = false) -> PaymentsUI {
        let plusPlanNames = ["vpnplus", "vpn2022"]
        let planNames = onlyPlusPlan ? ObfuscatedConstants.planNames.filter({ plusPlanNames.contains($0) }) : ObfuscatedConstants.planNames
        return PaymentsUI(payments: payments,
                          clientApp: ClientApp.vpn,
                          shownPlanNames: planNames,
                          customization: .init(inAppTheme: { .dark }))
    }

    private func handlePaymentsResponse(response: PaymentsUIResultReason, modalSource: UpsellEvent.ModalSource?) {
        switch response {
        case let .purchasedPlan(accountPlan: plan):
            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
            Task { [weak self] in
                await self?.delegate?.paymentTransactionDidFinish(modalSource: modalSource, newPlanName: plan.protonName)
            }
        case let .open(vc: _, opened: opened):
            assert(opened == true)
        case let .planPurchaseProcessingInProgress(accountPlan: plan):
            log.debug("Purchasing \(plan.protonName)", category: .iap)
        case .close:
            log.debug("Payments closed", category: .iap)
        case let .purchaseError(error: error):
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
        case .toppedUpCredits:
            log.debug("Credits topped up", category: .iap)
        case let .apiMightBeBlocked(message, originalError: error):
            log.error("\(message)", category: .connection, metadata: ["error": "\(error)"])

        }
    }
}

extension CorePlanService: StoreKitManagerDelegate {
    var isUnlocked: Bool {
        return true
    }

    var isSignedIn: Bool {
        authKeychain.username != nil
    }

    var activeUsername: String? {
        authKeychain.username
    }

    var userId: String? {
        authKeychain.userId
    }
}
