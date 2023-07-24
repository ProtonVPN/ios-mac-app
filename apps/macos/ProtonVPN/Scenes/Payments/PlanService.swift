//
//  PlanService.swift
//  vpncore - Created on 01.09.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCoreDataModel
import ProtonCorePayments
import vpncore

protocol PlanServiceFactory {
    func makePlanService() -> PlanService
}

protocol PlanService {
    var countriesCount: Int { get }
    func updateCountriesCount()
}

class UserCachedStatus: ServicePlanDataStorage {
    var servicePlansDetails: [Plan]?
    var defaultPlanDetails: Plan?
    var currentSubscription: Subscription?
    var credits: Credits?
    var paymentMethods: [PaymentMethod]?
    var paymentsBackendStatusAcceptsIAP: Bool = false
}

class AlertManager: AlertManagerProtocol {
    var title: String?
    var message: String = ""
    var confirmButtonTitle: String?
    var cancelButtonTitle: String?
    var confirmButtonStyle: AlertActionStyle = .default
    var cancelButtonStyle: AlertActionStyle = .default
    func showAlert(confirmAction: ActionCallback, cancelAction: ActionCallback) { }
}

// This class is currently only used for retrieving the count of countries for the upsell modal.
final class CorePlanService: PlanService {
    private let payments: Payments

    var countriesCount: Int = AccountPlan.plus.countriesCount

    init(networking: Networking) {
        payments = Payments(
            inAppPurchaseIdentifiers: ObfuscatedConstants.vpnIAPIdentifiers,
            apiService: networking.apiService,
            localStorage: UserCachedStatus(),
            alertManager: AlertManager(),
            reportBugAlertHandler: { _ in }
        )
    }

    func updateCountriesCount() {
        updateCountriesCount { [weak self] result in
            switch result {
            case .success(let count):
                self?.countriesCount = count
            case .failure:
                self?.countriesCount = AccountPlan.plus.countriesCount
            }
        }

    }

    private func updateCountriesCount(completion: @escaping (Result<Int, Error>) -> Void) {
        if let counts = payments.planService.countriesCount {
            return completion(.success(counts.maxCountries()))
        }
        payments.planService.updateCountriesCount { [weak self] in
            if let count = self?.payments.planService.countriesCount?.maxCountries() {
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
}
