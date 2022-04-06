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
import vpncore

protocol CouponViewModelDelegate: AnyObject {
    func loadingDidChange(isLoading: Bool)
    func errorDidChange(isError: Bool)
}

final class CouponViewModel {
    private(set) var isLoading: Bool = false {
        didSet {
            delegate?.loadingDidChange(isLoading: isLoading)
        }
    }
    private(set) var isError: Bool = false {
        didSet {
            delegate?.errorDidChange(isError: isError)
        }
    }

    weak var delegate: CouponViewModelDelegate?

    private let paymentsApiService: PaymentsApiService
    private let appSessionManager: AppSessionManager

    init(paymentsApiService: PaymentsApiService, appSessionManager: AppSessionManager) {
        self.paymentsApiService = paymentsApiService
        self.appSessionManager = appSessionManager
    }

    func applyPromoCode(code: String, completion: @escaping (Result<(), Error>) -> Void) {
        guard !code.isEmpty else {
            isError = true
            return
        }

        isError = false
        isLoading = true

        paymentsApiService.applyPromoCode(code: code) { [weak self] result in
            switch result {
            case let .failure(error):
                log.error("Failed to apply promo code", category: .app, metadata: ["error": "\(error)"])

                self?.isLoading = false
                self?.isError = true

                completion(.failure(error))

            case .success:
                log.info("Promo code applied, reloading data")

                // reload the user data
                self?.appSessionManager.attemptSilentLogIn { [weak self] result in
                    self?.isLoading = false

                    switch result {
                    case let .failure(error):
                        log.error("Failed to reload data after applying promo code", category: .app, metadata: ["error": "\(error)"])
                        self?.isError = true
                        completion(.failure(error))

                    case .success:
                        log.debug("Data reloaded after applying promo code", category: .app)
                        completion(.success)
                    }
                }
            }
        }
    }
}
