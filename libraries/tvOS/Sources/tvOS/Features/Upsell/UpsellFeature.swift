//
//  Created on 16/08/2024.
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
import ComposableArchitecture
import Dependencies
import StoreKit

@Reducer
struct UpsellFeature {
    @Dependency(\.paymentsClient) var client

    public typealias ActionSender = (Action) -> Void

    enum Action {
        case loadProducts
        case finishedLoadingProducts(Result<[Product], Error>)
        case attemptPurchase(Product)
        case onExit
    }

    @ObservableState
    enum State: Equatable {
        case loading
        case loaded([Product])
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadProducts:
                return .run { send in
                    await send(.finishedLoadingProducts(Result { try await client.getOptions() }))
                }

            case .finishedLoadingProducts(.success(let products)):
                let sortedProducts = products.sorted(by: {
                    guard let lhsUnit = $0.subscription?.subscriptionPeriod.unit,
                          let rhsUnit = $1.subscription?.subscriptionPeriod.unit else { return false }
                     return lhsUnit > rhsUnit // sort by unit, for example, .year is before .month.
                })
                state = .loaded(sortedProducts)
                return .none

            case .finishedLoadingProducts(.failure(let error)):
                return .none

            case .attemptPurchase(let product):
                return .run { send in
                    try await client.attemptPurchase(product)
                }
                
            case .onExit:
                return .none
            }
        }
    }
}
