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
import Strings

public protocol CouponViewModelFactory {
    func makeCouponViewModel() -> CouponViewModel
}

public protocol CouponViewModelDelegate: AnyObject {
    func loadingDidChange(isLoading: Bool)
    func errorDidChange(isError: Bool)
}

public final class CouponViewModel {
    public private(set) var isLoading: Bool = false {
        didSet {
            delegate?.loadingDidChange(isLoading: isLoading)
        }
    }
    public private(set) var isError: Bool = false {
        didSet {
            delegate?.errorDidChange(isError: isError)
        }
    }

    public weak var delegate: CouponViewModelDelegate?

    private let paymentsApiService: PaymentsApiService
    private let appSessionRefresher: AppSessionRefresherImplementation

    public init(paymentsApiService: PaymentsApiService, appSessionRefresher: AppSessionRefresherImplementation) {
        self.paymentsApiService = paymentsApiService
        self.appSessionRefresher = appSessionRefresher
    }

    public func applyPromoCode(code: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !code.isEmpty else {
            isError = true
            return
        }

        isError = false
        isLoading = true

        paymentsApiService.applyPromoCode(code: code.uppercased()) { [weak self] result in
            switch result {
            case let .failure(error):
                log.error("Failed to apply promo code", category: .app, metadata: ["error": "\(error)"])

                self?.isLoading = false
                self?.isError = true

                completion(.failure(error))

            case let .success(type):
                switch type {
                case .planUpgraded:
                    log.info("Promo code applied, reloading data", category: .app)

                    // reload the user data
                    self?.appSessionRefresher.attemptSilentLogIn { [weak self] result in
                        self?.isLoading = false

                        switch result {
                        case let .failure(error):
                            switch error {
                            case is CertificateRefreshError:
                                log.debug("Certificate refresh failed after data reload but the data reloaded successfully", category: .app)
                                completion(.success(Localizable.couponApplied))
                            default:
                                log.error("Failed to reload data after applying promo code", category: .app, metadata: ["error": "\(error)"])
                                completion(.success(Localizable.couponAppliedPlanNotUpgradedYet))
                            }
                        case .success:
                            log.debug("Data reloaded after applying promo code", category: .app)
                            completion(.success(Localizable.couponApplied))
                        }
                    }
                case .planNotUpgradedYet:
                    log.info("Promo code applied, not reloading data because the plan was not upgraded yet", category: .app)
                    completion(.success(Localizable.couponAppliedPlanNotUpgradedYet))
                }
            }
        }
    }
}
