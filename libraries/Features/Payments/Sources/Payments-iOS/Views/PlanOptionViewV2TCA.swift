//
//  Created on 05/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import PaymentsShared
import Strings
import SwiftUI
import Theme

private enum Constants {
    static let rowHeight: CGFloat = 64
}

struct PlanOptionViewV2TCA: View {
    enum State {
        case loading
        case loaded(option: PlanOptionV2, isSelected: Bool, discount: Int?)
    }

    let state: State

    var body: some View {
        switch state {
        case .loading:
            loadingView
        case let .loaded(option, isSelected, discount):
            loadedView(option: option, isSelected: isSelected, discount: discount)
        }
    }

    private var loadingView: some View {
        HStack(spacing: .themeSpacing8) {
            RoundedRectangle(cornerRadius: .themeRadius4)
                .frame(width: 120, height: 14)
            Spacer()
            RoundedRectangle(cornerRadius: .themeRadius4)
                .frame(width: 64, height: 14)
        }
        .foregroundStyle(Color(.text, .disabled))
        .padding(.themeSpacing16)
        .frame(height: Constants.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: .themeSpacing8)
                .style(withStroke: Color(.border), lineWidth: 1.0, fill: .clear)
        )
    }

    @ViewBuilder
    private func loadedView(option: PlanOptionV2, isSelected: Bool, discount: Int?) -> some View {
        HStack(spacing: .themeSpacing8) {
            Text(option.durationLabel ?? "")
                .themeFont(.body1(.regular))

            if let discount {
                Text(-abs(discount), format: .percent)
                    .themeFont(.overline(emphasised: true))
                    .padding(.horizontal, .themeSpacing4)
                    .padding(.vertical, .themeSpacing2)
                    .foregroundStyle(Color(.text, .inverted))
                    .background(Color(.icon, .vpnGreen))
                    .cornerRadius(.themeRadius4)
            }

            if option.purchaseType == .web {
                Text(Localizable.webOnlyFeature)
                    .themeFont(.overline(emphasised: true))
                    .textCase(.uppercase)
                    .padding(.horizontal, .themeSpacing6)
                    .padding(.vertical, .themeSpacing2)
                    .foregroundColor(Color(.text, .warning))
                    .background(
                        RoundedRectangle(cornerRadius: .themeSpacing4)
                            .style(withStroke: Color(.text, .warning), lineWidth: 1.0, fill: .clear)
                    )
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(option.displayPrice)
                    .themeFont(.body1(.bold))
                if option.amountOfMonths > 1 {
                    HStack(spacing: .zero) {
                        Text(option.pricePerMonth)
                        Text(Localizable.upsellPlansListOptionAmountPerMonth)
                    }
                    .font(.body3())
                    .foregroundColor(Color(.text, .weak))
                }
            }
        }
        .padding(.themeSpacing16)
        .frame(height: Constants.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: .themeSpacing8)
                .style(
                    withStroke: isSelected ? Color(.background, [.interactive, .strong]) : Color(.border),
                    lineWidth: isSelected ? 2.0 : 1.0,
                    fill: isSelected ? Color(.background, .weak) : .clear
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: .themeRadius8))
    }
}

#if DEBUG
    #Preview("Loading", traits: .sizeThatFitsLayout) {
        PlanOptionViewV2TCA(state: .loading)
            .padding()
    }

    #Preview("Selected IAP", traits: .sizeThatFitsLayout) {
        PlanOptionViewV2TCA(
            state: .loaded(
                option: .oneYear,
                isSelected: true,
                discount: -33
            )
        )
        .padding()
    }

    #Preview("Web Plan", traits: .sizeThatFitsLayout) {
        PlanOptionViewV2TCA(
            state: .loaded(
                option: .twoYearsWebPlan,
                isSelected: false,
                discount: nil
            )
        )
        .padding()
    }
#endif
