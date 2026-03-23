//
//  Created on 05/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import Dependencies
import DependenciesMacros
import Domain
import Foundation
import ProtonCorePaymentsV2
import StoreKit
import Strings
import VPNAppCore

public enum PaymentsAvailability: Equatable, Sendable {
    case available
    case unavailable(localizedReason: String?)
}

@DependencyClient
public struct PaymentsClient: Sendable {
    public var availability: @Sendable () async -> PaymentsAvailability = { .unavailable(localizedReason: nil) }
    public var retrievePlans: @Sendable () async throws -> [PlanOptionV2]
    public var availableDiscount: @Sendable (PlanOptionV2) -> Int?
    public var startWebCheckoutSession: @Sendable () async -> URL?
    public var purchase: @Sendable (PlanOptionV2) async throws -> Void
}

extension PaymentsClient: DependencyKey {
    public static let liveValue = PaymentsClient(
        availability: {
            @Dependency(\.paymentsPlanServiceV2) var planService
            guard planService.arePaymentsAllowed else {
                return .unavailable(localizedReason: Localizable.upgradeUnavailableOnTestflight)
            }
            do {
                let status = try await planService.fetchIAPStatus()
                if case let .disabled(localizedReason) = status {
                    return .unavailable(localizedReason: localizedReason)
                }
                return .available
            } catch {
                return .unavailable(localizedReason: error.localizedDescription)
            }
        },
        retrievePlans: {
            @Dependency(\.paymentsPlanServiceV2) var planService
            @Dependency(\.settingsStorage) var settingsStorage

            let appStoreCountryCodeOverride = settingsStorage.getEnvironment().localValuesOverrides["AppStoreCC"]?.lowercased()
            let userAppStoreCountryCode: String? = if let appStoreCountryCodeOverride {
                appStoreCountryCodeOverride
            } else {
                await planService.countryCode
            }
            let userIsEligibleFor2YPlan = userAppStoreCountryCode == "usa"
            let shouldShowTwoYearsWebPlan = userIsEligibleFor2YPlan && VPNFeatureFlagType.iapToWeb.enabled

            let composedPlans = try await planService.getAvailablePlans().filter { $0.plan.name == "vpn2022" }
            if composedPlans.isEmpty, !shouldShowTwoYearsWebPlan {
                throw LiveClientError.defaultPlanNotFound
            }

            liveContext.setAvailablePlans(composedPlans)
            var options: [PlanOptionV2] = composedPlans.map {
                PlanOptionV2(
                    id: $0.product.id,
                    storePricePerMonth: $0.storePricePerMonth,
                    amountOfMonths: $0.amountOfMonths,
                    durationLabel: $0.durationLabel,
                    displayPrice: $0.product.displayPrice,
                    pricePerMonth: $0.pricePerMonthLabel
                )
            }
            if shouldShowTwoYearsWebPlan {
                options.append(.twoYearsWebPlan)
            }
            return options
        },
        availableDiscount: { planOption in
            let mostExpensivePlan = liveContext.cachedMostExpensivePlan
            guard let mostExpensivePlan else { return nil }
            return ComposedPlan.discount(
                currentPrice: planOption.storePricePerMonth,
                comparedPrice: mostExpensivePlan.storePricePerMonth
            )
        },
        startWebCheckoutSession: {
            @Dependency(\.sessionService) var sessionService
            return await sessionService.getPlanSession(mode: .promo2yPlan)
        },
        purchase: { planOption in
            guard planOption.purchaseType != .web else {
                throw LiveClientError.invalidWebPurchaseRequest
            }
            guard let composedPlan = liveContext.plan(for: planOption.id) else {
                throw LiveClientError.planNotFoundInAvailableList(planOption.id)
            }
            guard let product = composedPlan.product as? Product else {
                throw LiveClientError.planMissingStoreProduct(planOption.id)
            }
            @Dependency(\.paymentsPlanServiceV2) var planService
            _ = try await planService.purchase(product)
        }
    )

    #if DEBUG
        public static let testValue = PaymentsClient(
            availability: { .available },
            retrievePlans: {
                [
                    .init(
                        id: "vpn_plus_1m",
                        storePricePerMonth: 9.99,
                        amountOfMonths: 1,
                        durationLabel: "1 month",
                        displayPrice: "$9.99",
                        pricePerMonth: "$9.99"
                    ),
                    .init(
                        id: "vpn_plus_1y",
                        storePricePerMonth: 6.66,
                        amountOfMonths: 12,
                        durationLabel: "1 year",
                        displayPrice: "$79.92",
                        pricePerMonth: "$6.66"
                    ),
                    .twoYearsWebPlan,
                ]
            },
            availableDiscount: { _ in nil },
            startWebCheckoutSession: { nil },
            purchase: { _ in }
        )
    #endif
}

enum LiveClientError: LocalizedError {
    case defaultPlanNotFound
    case invalidWebPurchaseRequest
    case planNotFoundInAvailableList(String)
    case planMissingStoreProduct(String)

    var errorDescription: String? {
        switch self {
        case .defaultPlanNotFound:
            "Default plan not found"
        case .invalidWebPurchaseRequest:
            "Web plan purchase was requested from IAP flow"
        case let .planNotFoundInAvailableList(planID):
            "Plan id \(planID) was not found in available plans list"
        case let .planMissingStoreProduct(planID):
            "Plan id \(planID) has no matching StoreKit Product"
        }
    }
}

private final class PaymentsLiveContext: @unchecked Sendable {
    private let lock = NSLock()
    private var availablePlans: [ComposedPlan] = []

    var cachedMostExpensivePlan: ComposedPlan? {
        lock.lock()
        defer { lock.unlock() }
        return availablePlans.max(by: { $0.storePricePerMonth < $1.storePricePerMonth })
    }

    func setAvailablePlans(_ plans: [ComposedPlan]) {
        lock.lock()
        availablePlans = plans
        lock.unlock()
    }

    func plan(for id: String) -> ComposedPlan? {
        lock.lock()
        defer { lock.unlock() }
        return availablePlans.first { $0.product.id == id }
    }
}

private let liveContext = PaymentsLiveContext()

public extension DependencyValues {
    var paymentsClient: PaymentsClient {
        get { self[PaymentsClient.self] }
        set { self[PaymentsClient.self] = newValue }
    }
}
