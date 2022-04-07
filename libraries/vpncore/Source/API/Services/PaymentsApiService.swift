//
//  Created on 05.04.2022.
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
import ProtonCore_Networking

public enum PaymentsApiServiceSuccess {
    case planUpgraded
    case planNotUpgradedYet
}

public protocol PaymentsApiServiceFactory {
    func makePaymentsApiService() -> PaymentsApiService
}

public protocol PaymentsApiService {
    func applyPromoCode(code: String, completion: @escaping (Result<PaymentsApiServiceSuccess, Error>) -> Void)
}

public final class PaymentsApiServiceImplementation: PaymentsApiService {
    private let networking: Networking
    private let vpnKeychain: VpnKeychainProtocol
    private let vpnApiService: VpnApiService

    public init(networking: Networking, vpnKeychain: VpnKeychainProtocol, vpnApiService: VpnApiService) {
        self.networking = networking
        self.vpnKeychain = vpnKeychain
        self.vpnApiService = vpnApiService
    }

    public func applyPromoCode(code: String, completion: @escaping (Result<PaymentsApiServiceSuccess, Error>) -> Void) {
        // store the user account plan before applying the promo code
        let originalPlan = (try? vpnKeychain.fetchCached())?.accountPlan

        // apply the promo code on the backend
        networking.request(PromoCodeRequest(code: code)) { [weak self] (result: Result<PromoCodeResponse, Error>) in
            switch result {
            case .success:
                log.debug("Applying promo code successful, checking if the plan is upgraded already", category: .app)
                // check if the plan got upgraded already
                self?.checkPlanUpgraded(originalPlan: originalPlan, retries: 1) { status in
                    completion(.success(status))
                }
            case let .failure(error):
                // return the most specific error to show the best error message
                let responseError = error as? ResponseError
                let specificError = responseError?.underlyingError ?? responseError ?? error
                completion(.failure(specificError))
            }
        }
    }

    private func checkPlanUpgraded(originalPlan: AccountPlan?, retries: Int, completion: @escaping (PaymentsApiServiceSuccess) -> Void) {
        // makes sure we do not try indefinitely
        guard retries >= 0 else {
            log.debug("No more retries to check if the plan is upgraded after applying promo code", category: .app)
            // tell the user the plan is not upgraded yet but will be in a few minutes
            completion(.planNotUpgradedYet)
            return
        }

        // each try introduces a slight delay to give the backend time to upgrade the plan
        // this is needed because applying promo code does not upgrade the plan immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            // check if the plan is upgraded already
            self?.vpnApiService.clientCredentials { result in
                switch result {
                case .failure:
                    log.debug("Error checking if the plan is upgraded after applying promo code, returning", category: .app)
                    // if a failure occurs just tell the user the plan is not upgraded yet but will be in a few minutes
                    completion(.planNotUpgradedYet)
                case let .success(credentials):
                    // the plan is still not upgraded, try again
                    if credentials.accountPlan == originalPlan {
                        log.debug("The plan is not yet upgraded after applying promo code, trying again", category: .app)
                        self?.checkPlanUpgraded(originalPlan: originalPlan, retries: retries - 1, completion: completion)
                    } else { // the plan has been upgraded
                        log.debug("The plan is upgraded after applying promo code", category: .app)
                        completion(.planUpgraded)
                    }
                }
            }
        }
    }
}
