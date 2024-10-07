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

import SwiftUI
import Strings
import Modals // Borrow logic from iOS OneClick until we migrate to PaymentsNG/StoreKit2
import struct StoreKit.Product

struct PurchaseOptionsView: View {
    
    let products: [PlanIAPTuple]

    let sendAction: UpsellFeature.ActionSender

    var body: some View {
        VStack {
            ForEach(products) { product in
                Button {
                    sendAction(.attemptPurchase(product))
                } label: {
                    buttonContent(product: product)
                }
                .buttonStyle(UpsellButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func buttonContent(product: Product) -> some View {
        if let subscription = product.subscription {
            HStack(spacing: .themeSpacing16) {
                headlineText("\(subscription.subscriptionPeriod)")
                Spacer()
                if subscription.subscriptionPeriod.unit == .year {
                    VStack {
                        headlineText("\(product.displayPrice)")
                        + bodyText(" /year")
                        bodyText(pricePerMonth(product))
                    }
                } else if subscription.subscriptionPeriod.unit == .month {
                    headlineText("\(product.displayPrice)")
                    + bodyText(" /month")
                } else {
                    headlineText("\(product.displayPrice)")
                }
            }
        }
    }

    func pricePerMonth(_ product: Product) -> String {
        let pricePerPeriod = product.price / 12
        let price = pricePerPeriod.formatted(product.priceFormatStyle)
        return "\(price)/month"
    }

    private func headlineText(_ text: String) -> Text {
        return Text(text)
            .font(.system(size: 38, weight: .regular))
    }

    private func bodyText(_ text: String) -> Text {
        return Text(text)
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

    // MARK: Legacy ProtonCorePayments

    @ViewBuilder
    private func buttonContent(product: PlanIAPTuple) -> some View {
        let planOption = product.planOption
        let planDuration = planOption.duration
        let planPrice = planOption.price
        let planPriceString = PriceFormatter.formatPlanPrice(price: planPrice.amount, locale: planPrice.locale)
        let pricePerMonthString = PriceFormatter.formatPlanPrice(price: planOption.pricePerMonth, locale: planPrice.locale)
        HStack(spacing: .themeSpacing16) {
            VStack {
                // > Apps offering auto-renewable subscriptions must include:
                // > Title of auto-renewing subscription, which may be the same as the in-app purchase product name
                // Plan title is hardcoded for now - we already reference VPN Plus in the coaxing view, and filter
                // plans based on the identifier `vpn2022`.
                headlineText("VPN Plus")
                bodyText(subscriptionPeriod(for: planOption))
            }
            Spacer()
            if planDuration.months == 12 {
                VStack {
                    headlineText(planPriceString)
                    + bodyText(" /year")
                    bodyText("\(pricePerMonthString) /month")
                }
            } else if planDuration == .oneMonth {
                headlineText(planPriceString)
                + bodyText(" /month")
            } else {
                headlineText(planPriceString)
            }
        }
    }

    private static let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private func subscriptionPeriod(for planOption: PlanOption) -> String {
        Self.dateComponentsFormatter.string(from: planOption.duration.components)
            ?? planOption.duration.components.fallbackDuration
    }
}

enum PriceFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    static func formatPlanPrice(price: Double, locale: Locale) -> String {
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: price)) ?? ""
    }
}

private extension DateComponents {
    var isMoreThanOneMonth: Bool {
        amountOfMonths > 1
    }

    // This property is a fallback in case where DateComponentsFormatter returns `nil`
    // Not ideal but should do the job
    var fallbackDuration: String {
        var duration: String = ""
        if let year, year != 0 {
            duration += Localizable.planDurationYear(year)
        }
        if let month, month != 0 {
            if !duration.isEmpty {
                duration += ", "
            }
            duration += Localizable.planDurationMonth(month)
        }
        if duration.isEmpty {
            assertionFailure("This components receiver is invalid")
        }
        return duration
    }
}
