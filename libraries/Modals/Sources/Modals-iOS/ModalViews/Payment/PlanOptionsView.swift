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

@MainActor
struct PlanOptionsView: View {
    private static let maxContentWidth: CGFloat = 480
    private static let imagePadding: EdgeInsets = .init(top: 0, leading: 52, bottom: 24, trailing: 52)

    let modalType: ModalType

    @ObservedObject var viewModel: PlanOptionsListViewModel

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
        .overlay(
            purchaseInProgressView
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.isPurchaseInProgress)
        )
        .background(Color(.background))
    }

    @ViewBuilder
    private var purchaseInProgressView: some View {
        if viewModel.isPurchaseInProgress {
            ZStack {
                Color(white: 0, opacity: 0.75)
                ProgressView()
                    .tint(.primary)
                    .controlSize(.large)
            }
            .ignoresSafeArea()
        }
    }
}

#if swift(>=5.9)
#Preview("Classic") {
    let scheduler: AnySchedulerOf<DispatchQueue> = .main
    let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(retrievePlans: { plans }, validate: { _ in
        try? await scheduler.sleep(for: .milliseconds((2000...3000).randomElement()!))
    })
    return PlanOptionsView(modalType: .subscription, viewModel: .init(client: client))
}

#Preview("Loading") {
    let scheduler: AnySchedulerOf<DispatchQueue> = .main
    let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(
        retrievePlans: {
            try? await scheduler.sleep(for: .milliseconds((500...2000).randomElement()!))
            return plans
        },
        validate: { _ in
            try? await scheduler.sleep(for: .milliseconds((2000...3000).randomElement()!))
        })
    return PlanOptionsView(modalType: .subscription, viewModel: .init(client: client))
}

#Preview("Currencies") {
    let plans: [PlanOption] = [
        .init(duration: .twoYears, price: .init(amount: 145, currency: "USD")),
        .init(duration: .oneYear, price: .init(amount: 85, currency: "EUR")),
        .init(duration: .threeMonths, price: .init(amount: 33, currency: "JPY")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(retrievePlans: { plans }, validate: { _ in () })
    return PlanOptionsView(modalType: .subscription, viewModel: .init(client: client))
}
#else
struct PlansOptionsListView_Previews: PreviewProvider {
    static let scheduler: AnySchedulerOf<DispatchQueue> = .main
    static let classicPlans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    static let classicClient: PlansClient = .init(retrievePlans: { classicPlans }, validate: { _ in
        try? await scheduler.sleep(for: .milliseconds((2000...3000).randomElement()!))
    })
    static let loadingClient: PlansClient = .init(
        retrievePlans: {
            try? await scheduler.sleep(for: .milliseconds((500...2000).randomElement()!))
            return classicPlans
        },
        validate: { _ in
            try? await scheduler.sleep(for: .milliseconds((2000...3000).randomElement()!))
        })
    static let currenciesPlans: [PlanOption] = [
        .init(duration: .twoYears, price: .init(amount: 145, currency: "USD")),
        .init(duration: .oneYear, price: .init(amount: 85, currency: "EUR")),
        .init(duration: .threeMonths, price: .init(amount: 33, currency: "JPY")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    static let currenciesClient: PlansClient = .init(retrievePlans: { currenciesPlans }, validate: { _ in () })

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
