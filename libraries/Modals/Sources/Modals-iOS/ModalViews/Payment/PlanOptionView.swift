//
//  Created on 28/02/2024.
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
import Modals

private enum Constants {
    static let planOptionViewRowHeight: CGFloat = 64
}

struct PlanOptionView: View {
    let planOption: PlanOption

    let isLoading: Bool
    let isSelected: Bool
    private let discount: Int?

    init(planOption: PlanOption, isLoading: Bool, isSelected: Bool, discount: Int? = nil) {
        self.planOption = planOption
        self.isLoading = isLoading
        self.isSelected = isSelected
        self.discount = discount
    }

    var body: some View {
        if isLoading {
            PlanOptionLoadingView()
        } else {
            PlanOptionLoadedView(planOption: planOption, 
                                 discount: discount,
                                 isSelected: isSelected)
        }
    }
}

private struct PlanOptionLoadedView: View {
    private static let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    let planOption: PlanOption
    let discount: Int?

    let isSelected: Bool

    var body: some View {
        let planDuration = planOption.duration
        let planPrice = planOption.price

        HStack(spacing: .themeSpacing8) {
            let planDurationString = Self.dateComponentsFormatter.string(from: planDuration.components) ?? planDuration.components.fallbackDuration
            Text(planDurationString)
                .themeFont(.body1(.regular))

            if let discount {
                PlanDiscountBadgeView(discount: discount)
            }

            Spacer()

            VStack(alignment: .trailing) {
                HStack(alignment: .bottom, spacing: .zero) {
                    Text(PriceFormatter.formatPlanPrice(price: planPrice.amount, locale: planPrice.locale))
                        .themeFont(.body1(.bold))
                    Text(planDuration.periodDescription)
                        .themeFont(.body3())
                        .foregroundColor(Color(.text, .weak))
                }

                if planDuration.components.isMoreThanOneMonth {
                    let amountPerMonth = Double(planPrice.amount) / Double(planDuration.components.amountOfMonths)

                    HStack(spacing: .zero) {
                        Text(PriceFormatter.formatPlanPrice(price: amountPerMonth,
                                                            locale: planPrice.locale))
                        Text(Localizable.upsellPlansListOptionAmountPerMonth)
                    }
                    .font(.body3())
                    .foregroundColor(Color(.text, .weak))
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

enum PriceFormatter {
    private static var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    static func formatPlanPrice(price: Double, locale: Locale) -> String {
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: price)) ?? ""
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

// MARK: - Helpers

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

extension PlanDuration {
    var periodDescription: String {
        components.isMoreThanOneMonth 
            ? Localizable.upsellPlansListOptionAmountPerYear
            : Localizable.upsellPlansListOptionAmountPerMonth
    }
}

#if swift(>=5.9)
#Preview("Unselected") {
    let planOptionMonth = PlanOption(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    let planOptionYear = PlanOption(duration: .oneYear, price: .init(amount: 100, currency: "CHF"))
    return VStack {
        PlanOptionView(planOption: planOptionMonth,
                       isLoading: false,
                       isSelected: false,
                       discount: planOptionMonth.discount(comparedTo: planOptionYear))
        PlanOptionView(planOption: planOptionYear, 
                       isLoading: false,
                       isSelected: false,
                       discount: planOptionYear.discount(comparedTo: planOptionMonth))
    }
}

#Preview("Selected") {
    let planOption = PlanOption(duration: .oneYear, price: .init(amount: 85, currency: "CHF"))
    return PlanOptionView(planOption: planOption, isLoading: false, isSelected: true, discount: 35)
}

#Preview("RTL") {
    let planOption = PlanOption(duration: .oneYear, price: .init(amount: 85, currency: "CHF"))
    return PlanOptionView(planOption: planOption, isLoading: false, isSelected: true, discount: 35)
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Loading") {
    let planOption = PlanOption(duration: .oneYear, price: .init(amount: 85, currency: "CHF"))
    return PlanOptionView(planOption: planOption, isLoading: true, isSelected: false, discount: 35)
}

#Preview("Annoying Duration") {
    let planOption = PlanOption(
        duration: .init(components: DateComponents(year: 2, month: 6))!,
        price: .init(amount: 85, currency: "CHF")
    )
    return PlanOptionView(planOption: planOption, isLoading: false, isSelected: false, discount: 35)
}

#Preview("Badge") {
    PlanDiscountBadgeView(discount: 50)
}
#else
struct PlanOptionView_Provider: PreviewProvider {
    static let planOption1 = PlanOption(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    static let planOption2 = PlanOption(duration: .oneYear, price: .init(amount: 85, currency: "CHF"))
    static let annoyingPlan = PlanOption(
        duration: .init(components: DateComponents(year: 2, month: 6))!,
        price: .init(amount: 85, currency: "CHF")
    )

    static var previews: some View {
        PlanOptionView(planOption: planOption1, isLoading: false, isSelected: false)
            .previewDisplayName("Unselected")
        PlanOptionView(planOption: planOption2, isLoading: false, isSelected: true, discount: 35)
            .previewDisplayName("Selected")
        PlanOptionView(planOption: planOption2, isLoading: true, isSelected: false)
            .previewDisplayName("Loading")
        PlanOptionView(planOption: annoyingPlan, isLoading: false, isSelected: false, discount: 35)
            .previewDisplayName("Annoying Duration")
        PlanDiscountBadgeView(discount: 50)
            .previewDisplayName("Badge")
    }
}
#endif
