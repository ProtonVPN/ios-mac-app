//
//  Created on 22/08/2024.
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

import ModalsServices // Borrow logic from iOS OneClick
import Strings
import SwiftUI

struct PurchaseOptionsView: View {
    let products: [PlanOption]

    let sendAction: UpsellFeature.ActionSender

    var body: some View {
        VStack {
            ForEach(products, id: \.self) { planOption in
                Button {
                    sendAction(.attemptPurchase(planOption))
                } label: {
                    buttonContent(planOption: planOption)
                }
                .buttonStyle(UpsellButtonStyle())
            }
        }
    }

    private func headlineText(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 38, weight: .regular))
    }

    private func bodyText(_ text: String) -> Text {
        Text(text)
            .font(.body)
            .fontWeight(.regular)
            .foregroundStyle(Color(.text, .weak))
    }

    private func badge(discount: Int) -> some View {
        Text(verbatim: "-\(discount)%")
            .font(.body)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(Color(.text, .inverted))
            .background(Color(.icon, .vpnGreen))
            .cornerRadius(.themeRadius8)
            .hidden()
    }

    @ViewBuilder
    private func buttonContent(planOption: PlanOption) -> some View {
        HStack(spacing: .themeSpacing16) {
            VStack(alignment: .leading) {
                // > Apps offering auto-renewable subscriptions must include:
                // > Title of auto-renewing subscription, which may be the same as the in-app purchase product name
                // Plan title is hardcoded for now - we already reference VPN Plus in the coaxing view, and filter
                // plans based on the identifier `vpn2022`.
                headlineText("VPN Plus")
                bodyText(subscriptionPeriod(for: planOption))
            }
            Spacer()
            VStack(alignment: .trailing) {
                if planOption.amountOfMonths == 12 {
                    headlineText(planOption.displayPrice)
                        + bodyText(" /year")
                    bodyText("\(planOption.pricePerMonth) /month")
                } else if planOption.amountOfMonths == 1 {
                    headlineText(planOption.displayPrice)
                        + bodyText(" /month")
                } else {
                    headlineText(planOption.displayPrice)
                }
            }
        }
    }

    private func subscriptionPeriod(for planOption: PlanOption) -> String {
        planOption.durationLabel ?? "" // if `durationLabel` is `nil` then it's one-time purchase that's not present now
    }
}
