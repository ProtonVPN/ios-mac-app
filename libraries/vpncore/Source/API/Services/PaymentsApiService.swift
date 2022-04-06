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

public protocol PaymentsApiServiceFactory {
    func makePaymentsApiService() -> PaymentsApiService
}

public protocol PaymentsApiService {
    func applyPromoCode(code: String, completion: @escaping (Result<(), Error>) -> Void)
}

public final class PaymentsApiServiceImplementation: PaymentsApiService {
    private let networking: Networking

    public init(networking: Networking) {
        self.networking = networking
    }

    public func applyPromoCode(code: String, completion: @escaping (Result<(), Error>) -> Void) {
        let request = PromoCodeRequest(code: code)
        networking.request(request) { (result: Result<PromoCodeResponse, Error>) in
            switch result {
            case .success:
                completion(.success)
            case let .failure(error):
                let responseError = error as? ResponseError
                let specificError = responseError?.underlyingError ?? responseError ?? error
                completion(.failure(specificError))
            }
        }
    }
}
