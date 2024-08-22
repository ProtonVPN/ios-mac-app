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
import struct StoreKit.Product

struct PurchaseOptionsView: View {
    
    let products: [Product]

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
                if subscription.subscriptionPeriod.unit == .year {
                    badge(discount: 35)
                }
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
            .hidden() // TODO: Actually calculate the discount and unhide the badge
    }
}

