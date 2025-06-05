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

import Combine
import Dependencies
import Foundation
import ModalsServices // Borrow logic from iOS OneClick until we migrate to PaymentsNG/StoreKit2
import ProtonCorePaymentsV2
import StoreKit

enum PaymentsError: Error, CustomStringConvertible {
    case planNotFound(String)
    case iapDisabled

    var code: Int? {
        switch self {
        case .iapDisabled:
            nil

        case .planNotFound:
            -1
        }
    }

    var codeSuffix: String? {
        code.map { "(\($0))" }
    }

    /// Default error description, suffixed with the code if it has one, to ease error identification.
    var description: String {
        ["In-App Purchases are temporarily not available.", codeSuffix]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

struct PaymentsClient: Sendable, DependencyKey {
    let startObserving: @Sendable () async -> AsyncStream<TransactionHandlerState>
    let getOptions: @Sendable () async throws -> [PlanOption]
    let attemptPurchase: @Sendable (PlanOption) async throws -> ComposedPlan?

    static let liveValue: PaymentsClient = {
        let planService = Dependency(\.planService).wrappedValue

        return .init(
            startObserving: {
                var cancellable: AnyCancellable?
                return AsyncStream { continuation in
                    cancellable = planService.transactionProgress.sink { event in
                        continuation.yield(event)
                    }
                    continuation.onTermination = { @Sendable _ in
                        cancellable?.cancel()
                    }
                }
            },
            getOptions: {
                // IAP availability depends on currently logged in user account.
                // Let's update it in case a different user is logged in than at app launch time.
                try await planService.fetchAppleStatus()
                guard planService.iapSupportStatus.isEnabled else {
                    throw PaymentsError.iapDisabled
                }

                let planOptions = try await planService.planOptions()
                return planOptions.map { $0 }
            },
            attemptPurchase: { planOption in
                try await planService.buyPlan(planOption: planOption)
            }
        )
    }()

    static let testValue: PaymentsClient = .init(
        startObserving: { .init(unfolding: { nil }) },
        getOptions: unimplemented(),
        attemptPurchase: unimplemented(placeholder: nil)
    )
}

extension DependencyValues {
    var paymentsClient: PaymentsClient {
        get { self[PaymentsClient.self] }
        set { self[PaymentsClient.self] = newValue }
    }
}
