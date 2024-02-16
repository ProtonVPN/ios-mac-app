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
import CombineSchedulers
import Modals

struct PlanOptionsView: View {
    private static let maxContentWidth: CGFloat = 480
    private static let imagePadding: EdgeInsets = .init(top: 0, leading: 52, bottom: 24, trailing: 52)

    let modalType: ModalType
    let viewModel: PlanOptionsListViewModel

    var body: some View {
        let modalModel = modalType.modalModel()

        UpsellBackgroundView(showGradient: modalModel.shouldAddGradient) {
            VStack {
                ModalBodyView(modalType: modalType, imagePadding: Self.imagePadding)

                Spacer()

                PlanOptionsListView(viewModel: viewModel)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.bottom, .themeSpacing8)
            .frame(maxWidth: Self.maxContentWidth)
        }
        .background(Color(.background))
    }
}

#if swift(>=5.9)
#Preview("Classic") {
    let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(retrievePlans: { plans })
    return PlanOptionsView(modalType: .subscription, viewModel: .init(client: client))
}

#Preview("Loading") {
    let scheduler: AnySchedulerOf<DispatchQueue> = .main
    let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(retrievePlans: {
        try? await scheduler.sleep(for: .milliseconds((500...2000).randomElement()!))
        return plans
    })
    return PlanOptionsView(modalType: .subscription, viewModel: .init(client: client))
}

#Preview("Currencies") {
    let plans: [PlanOption] = [
        .init(duration: .twoYears, price: .init(amount: 145, currency: "USD")),
        .init(duration: .oneYear, price: .init(amount: 85, currency: "EUR")),
        .init(duration: .threeMonths, price: .init(amount: 33, currency: "JPY")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF")),
        .init(duration: .init(components: .init(year: 0)), price: .init(amount: 0, currency: "EUR"))
    ]
    let client: PlansClient = .init(retrievePlans: { plans })
    return PlanOptionsView(modalType: .subscription, viewModel: .init(client: client))
}
#else
struct PlansOptionsListView_Previews: PreviewProvider {
    static let scheduler: AnySchedulerOf<DispatchQueue> = .main
    static let classicPlans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    static let classicClient: PlansClient = .init(retrievePlans: { classicPlans })
    static let loadingClient: PlansClient = .init(retrievePlans: {
        try? await scheduler.sleep(for: .milliseconds((500...2000).randomElement()!))
        return classicPlans
    })
    static let currenciesPlans: [PlanOption] = [
        .init(duration: .twoYears, price: .init(amount: 145, currency: "USD")),
        .init(duration: .oneYear, price: .init(amount: 85, currency: "EUR")),
        .init(duration: .threeMonths, price: .init(amount: 33, currency: "JPY")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF")),
        .init(duration: .init(components: .init(year: 0)), price: .init(amount: 0, currency: "EUR"))
    ]
    static let currenciesClient: PlansClient = .init(retrievePlans: { currenciesPlans })

    static var previews: some View {
        PlanOptionsView(modalType: .subscription, viewModel: .init(client: classicClient))
            .previewDisplayName("Classic")
        PlanOptionsView(modalType: .subscription, viewModel: .init(client: loadingClient))
            .previewDisplayName("Loading")
        PlanOptionsView(modalType: .subscription, viewModel: .init(client: currenciesClient))
            .previewDisplayName("Currencies")
    }
}
#endif
