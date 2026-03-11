//
//  Created on 21.11.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation
import SwiftUI

import Dependencies

import ProtonCorePaymentsV2

import Domain
import LegacyCommon
import Payments
import Strings
import Theme
import VPNAppCore

struct PaymentsSettingsView: View {
    @Dependency(\.paymentsPlanServiceV2) private var planServiceV2
    private let alertService: CoreAlertService

    init(alertService: CoreAlertService) {
        self.alertService = alertService
    }

    func recoverPurchase() async {
        var purchase: CurrentSubscriptionResponse?
        var recovered = false
        var actionError: Error?
        do {
            purchase = try await planServiceV2.restorePurchase()
        } catch {
            actionError = error
            log.error("Couldn't restore purchase: \(error)")
        }

        do {
            try await planServiceV2.recoverTransaction()
            recovered = true
        } catch {
            actionError = error
            log.error("Couldn't recover transaction: \(error)")
        }

        let variant: PaymentRestorationAlert.Variant = if let purchase {
            .purchaseRestored(name: purchase.name ?? "VPN")
        } else if recovered {
            .transactionRecovered
        } else if let actionError {
            .error(actionError)
        } else {
            .error(CommonVpnError.paymentsDataMissing)
        }

        alertService.push(alert: PaymentRestorationAlert(variant))
    }

    var body: some View {
        VStack(spacing: .themeSpacing16) {
            Text(Localizable.restorePurchaseDetail)
                .themeFont(.body1(.regular))

            Divider()
                .background(Color(.border, .weak))

            Button(Localizable.restorePurchase) {
                Task {
                    await recoverPurchase()
                }
            }

            Divider()
                .background(Color(.border, .weak))

            Spacer()
        }
        .padding(.themeSpacing16)
        .background(Color(.background))
    }
}

#Preview {
    PaymentsSettingsView(alertService: CoreAlertServiceDummy())
}
