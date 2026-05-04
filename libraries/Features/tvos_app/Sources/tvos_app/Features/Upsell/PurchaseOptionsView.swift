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

import Dependencies
import Payments
import Strings
import SwiftUI

struct PurchaseOptionsView: View {
    let products: [PlanOptionV2]
    let introRenewalDates: [String: Date]

    let sendAction: UpsellFeature.ActionSender

    @FocusState private var focusedPlanID: String?

    private var selectedPlan: PlanOptionV2? {
        let id = focusedPlanID ?? products.first?.id
        return products.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing16) {
            ForEach(products, id: \.id) { planOption in
                Button {
                    sendAction(.attemptPurchase(planOption))
                } label: {
                    buttonContent(planOption: planOption)
                }
                .buttonStyle(UpsellButtonStyle())
                .focused($focusedPlanID, equals: planOption.id)
            }

            if let plan = selectedPlan, let footer = introductoryFooter(for: plan) {
                footerText(footer)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func headlineText(_ text: String) -> Text {
        Text(verbatim: text)
            .font(.system(size: 38, weight: .regular))
    }

    private func bodyText(_ text: String) -> Text {
        Text(verbatim: text)
            .font(.body)
            .fontWeight(.regular)
            .foregroundStyle(Color(.text, .weak))
    }

    private func footerText(_ text: String) -> Text {
        Text(verbatim: text)
            .font(.caption)
            .fontWeight(.regular)
            .foregroundStyle(Color(.text, .weak))
    }

    /// - Note: This isn't yet plumbed in, the logic from the iOS Payments client is too awkward to move over here.
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

    private func buttonContent(planOption: PlanOptionV2) -> some View {
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
                let price = planOption.introDisplayPrice ?? planOption.displayPrice
                let perMonth = planOption.introDisplayPricePerMonth ?? planOption.pricePerMonth
                // We don't want to show the "per period" part if the price is introductory, since that might suggest
                // that the renewal amount is less than it actually is. Still show the per-month cost for the initial
                // period for the yearly plan, however, since it's useful information.
                if planOption.amountOfMonths == 12 {
                    headlineText("\(price)\(planOption.hasIntroOffer ? "" : Localizable.perYear)")
                    bodyText("\(perMonth)\(Localizable.perMonth)")
                } else if planOption.amountOfMonths == 1 {
                    headlineText("\(price)\(planOption.hasIntroOffer ? "" : Localizable.perMonth)")
                } else {
                    headlineText(price)
                }
            }
        }
    }

    private func subscriptionPeriod(for planOption: PlanOptionV2) -> String {
        planOption.durationLabel ?? "" // if `durationLabel` is `nil` then it's one-time purchase that's not present now
    }

    private func introductoryFooter(for planOption: PlanOptionV2) -> String? {
        guard let introRenewalDate = introRenewalDates[planOption.id] else { return nil }
        let dateString = DateFormatter.renewalDateFormatter.string(from: introRenewalDate)
        return planOption.introductoryFooter(renewingOn: dateString)
    }
}

private extension DateFormatter {
    static var renewalDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .long
        return formatter
    }
}

#Preview {
    PurchaseOptionsView(
        products: [.oneMonth, .oneYear],
        introRenewalDates: ["1": Date(), "2": Date()],
        sendAction: { _ in }
    )
}
