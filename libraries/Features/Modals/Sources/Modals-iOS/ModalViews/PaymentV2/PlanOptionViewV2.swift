//
//  Created on 07/07/2025 by Max Kupetskyi.
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

import ModalsServices
import ModalsShared
import Strings
import SwiftUI

private enum Constants {
    static let planOptionViewRowHeight: CGFloat = 64
}

struct PlanOptionViewV2: View {
    enum State {
        case loading
        case loaded(option: PlanOptionV2, isSelected: Bool, discount: Int?)
    }

    let state: State

    init(state: State) {
        self.state = state
    }

    var body: some View {
        switch state {
        case .loading:
            PlanOptionLoadingView()
        case let .loaded(planOption, isSelected, discount):
            PlanOptionLoadedView(
                planOption: planOption,
                discount: discount,
                isSelected: isSelected
            )
        }
    }
}

private struct PlanOptionLoadedView: View {
    private enum AccessibilityIdentifier {
        static let planOptionDuration: String = "plan_option_duration"
        static let planOptionAmount: String = "plan_option_amount"
    }

    let planOption: PlanOptionV2
    let discount: Int?

    let isSelected: Bool

    var body: some View {
        HStack(spacing: .themeSpacing8) {
            let planDurationString: String = planOption.durationLabel ?? "" // if `durationLabel` is `nil` then it's one-time purchase that's not present now
            Text(planDurationString)
                .themeFont(.body1(.regular))
                .accessibilityIdentifier(AccessibilityIdentifier.planOptionDuration)

            if let discount {
                PlanDiscountBadgeView(discount: discount)
            }

            if planOption.purchaseType == .web {
                PlanWebOnlyTagView()
            }

            Spacer()

            VStack(alignment: .trailing) {
                HStack(alignment: .bottom, spacing: .zero) {
                    Text(planOption.displayPrice)
                        .themeFont(.body1(.bold))
                        .accessibilityIdentifier(AccessibilityIdentifier.planOptionAmount)
                }
                .accessibilityElement(children: .combine)

                if planOption.amountOfMonths > 1 {
                    HStack(spacing: .zero) {
                        Text(planOption.pricePerMonth)
                        Text(Localizable.upsellPlansListOptionAmountPerMonth)
                    }
                    .font(.body3())
                    .foregroundColor(Color(.text, .weak))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.themeSpacing16)
        .frame(height: Constants.planOptionViewRowHeight)
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

private struct PlanOptionLoadingView: View {
    private static let loadingTitleWidth: CGFloat = 120
    private static let loadingPriceWidth: CGFloat = 64
    private static let loadingViewsHeight: CGFloat = 14

    var body: some View {
        HStack(spacing: .themeSpacing8) {
            RoundedRectangle(cornerRadius: .themeRadius4)
                .frame(width: Self.loadingTitleWidth, height: Self.loadingViewsHeight)

            Spacer()

            RoundedRectangle(cornerRadius: .themeRadius4)
                .frame(width: Self.loadingPriceWidth, height: Self.loadingViewsHeight)
        }
        .foregroundStyle(Color(.text, .disabled))
        .padding(.themeSpacing16)
        .frame(height: Constants.planOptionViewRowHeight)
        .background(
            RoundedRectangle(cornerRadius: .themeSpacing8)
                .style(withStroke: Color(.border), lineWidth: 1.0, fill: .clear)
        )
    }
}

private struct PlanDiscountBadgeView: View {
    let discount: Int

    init(discount: Int) {
        self.discount = -abs(discount)
    }

    var body: some View {
        Text(discount, format: .percent)
            .themeFont(.overline(emphasised: true))
            .padding(.horizontal, .themeSpacing4)
            .padding(.vertical, .themeSpacing2)
            .foregroundStyle(Color(.text, .inverted))
            .background(Color(.icon, .vpnGreen))
            .cornerRadius(.themeRadius4)
    }
}

private struct PlanWebOnlyTagView: View {
    var body: some View {
        Text(Localizable.webOnlyFeature)
            .themeFont(.overline(emphasised: true))
            .textCase(.uppercase)
            .padding(.horizontal, .themeSpacing6)
            .padding(.vertical, .themeSpacing2)
            .foregroundColor(Color(.text, .warning))
            .cornerRadius(.themeRadius4)
            .background(
                RoundedRectangle(cornerRadius: .themeSpacing4)
                    .style(withStroke: Color(.text, .warning), lineWidth: 1.0, fill: .clear)
            )
    }
}

#if DEBUG
    #Preview("Unselected") {
        let planOptionMonth = PlanOptionV2.oneMonth
        let planOptionYear = PlanOptionV2.oneYear
        return VStack {
            PlanOptionViewV2(
                state: .loaded(option: planOptionMonth, isSelected: false, discount: nil)
            )
            PlanOptionViewV2(
                state: .loaded(option: planOptionYear, isSelected: false, discount: 33)
            )
        }
    }

    #Preview("Selected") {
        let planOption = PlanOptionV2.oneYear
        return PlanOptionViewV2(state: .loaded(option: planOption, isSelected: true, discount: 35))
    }

    #Preview("RTL") {
        let planOption = PlanOptionV2.oneYear
        return PlanOptionViewV2(state: .loaded(option: planOption, isSelected: true, discount: 35))
            .environment(\.layoutDirection, .rightToLeft)
    }

    #Preview("Loading") {
        PlanOptionViewV2(state: .loading)
    }

    #Preview("Badge") {
        PlanDiscountBadgeView(discount: 50)
    }
#endif
