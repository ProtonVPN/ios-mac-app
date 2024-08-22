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
import Dependencies
import PaymentsNG
import struct StoreKit.Product
import struct StoreKit.Transaction

enum PaymentsEnvironment: DependencyKey {
    static let liveValue: EnvURLType = .custom(envUrl: "vpn-api.proton.me")
}

struct PaymentsClient: Sendable, DependencyKey {

    var setHeaders: @Sendable ([APIHeader: String]) async -> Void
    var getOptions: @Sendable () async throws -> [Product]
    var attemptPurchase: @Sendable (Product) async throws -> Void

    static var liveValue: PaymentsClient = {
        let environment = Dependency(\.paymentsEnvironment).wrappedValue
        let credentials = Dependency(\.authKeychain).wrappedValue.fetch()! // TODO: Let's handle this more gracefully if possible

        let remoteManager = RemoteManager(requestHTTPHeader: [
            .appVersion: "appletv-vpn@1.0.0-dev", // TODO: use real dependency
            .sessionId: credentials.sessionId,
            .authorization: credentials.accessToken,
            .accept: "application/vnd.protonmail.v1+json",
            .contentType: "application/json"
        ])

        let storeKitWrapper = StoreKitWrapper(environment: environment, remoteManager: remoteManager)

        let outsideTransactions = Task {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            // Skipping this results in a runtime warning from StoreKit.
            // Could it lead to the StoreKit purchase not being recognised by ChargeBee -> VPN backend?
            for await verificationResult in Transaction.updates {
                guard case .verified(let transaction) = verificationResult else {
                    log.error("Unverified transaction")
                    return
                }

                log.info("Processing outside transaction: \(transaction)")
                // Is this something PaymentsNG should handle?
                // storeKitWrapper.processTransaction(transaction)
            }
        }

        return .init(
            setHeaders: { headers in
                // TODO: Update headers
                // `RemoteManager` uses headers passed to it on initialisation.
                // If the user changes, or the access token expires, we will run into problems until the headers are updated
                // At the moment, at the time of initialization of PaymentsClient, we will pass the correct headers.
                // But if the user logs out, and back in, it will try to reuse the previous user's session ID and access token.
            },
            getOptions: {
                let plansRequest = RequestType.availablePlans(currency: nil, vendor: "apple", state: nil, timeStamp: nil)
                let plansRequestURL = try PaymentsAPIs(envURL: environment).url(for: plansRequest)
                let plansResponse: AvailablePlans = try await remoteManager.getFromURL(plansRequestURL.url)

                let plans = plansResponse.plans.filter { $0.name == "vpn2022" }
                let instances = plans.flatMap { $0.instances }
                let ids = instances.compactMap { $0.vendors.apple?.productID }

                return await storeKitWrapper.getStoreProducts(ids)
            },
            attemptPurchase: { product in
                try await storeKitWrapper.purchase(product, planName: product.displayName, planCycle: 1)
            }
        )
    }()

}

extension DependencyValues {
    var paymentsEnvironment: EnvURLType {
        get { self[PaymentsEnvironment.self] }
        set { self[PaymentsEnvironment.self] = newValue }
    }

    var paymentsClient: PaymentsClient {
        get { self[PaymentsClient.self] }
        set { self[PaymentsClient.self] = newValue }
    }
}
