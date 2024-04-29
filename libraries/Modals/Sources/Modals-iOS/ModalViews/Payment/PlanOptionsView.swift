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
import Modals

struct PlanOptionsView: View {
    private static let imagePadding: EdgeInsets = EdgeInsets(top: 0, leading: 52, bottom: 24, trailing: 52)
    private static let maxContentWidth: CGFloat = 480

    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: PlanOptionsListViewModel

    let modalType: ModalType
    let displayBodyFeatures: Bool

    init(viewModel: PlanOptionsListViewModel, modalType: ModalType, displayBodyFeatures: Bool = false) {
        self.modalType = modalType
        self.displayBodyFeatures = displayBodyFeatures
        self.viewModel = viewModel
    }

    var body: some View {
        let modalModel = modalType.modalModel(legacy: displayBodyFeatures)
        let showSecondaryButton = displayBodyFeatures

        UpsellBackgroundView(showGradient: modalModel.shouldAddGradient) {
            VStack {
                ModalBodyView(modalType: modalType, displayBodyFeatures: displayBodyFeatures, imagePadding: imagePadding)

                Spacer()

                PlanOptionsListView(viewModel: viewModel, showSecondaryButton: showSecondaryButton)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.bottom, .themeSpacing8)
            .safeAreaInset(edge: .top) {
                if !showSecondaryButton {
                    navigationBar
                }
            }
            .frame(maxWidth: Self.maxContentWidth)
        }
        .overlay(
            purchaseInProgressView
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.isPurchaseInProgress)
        )
        .background(Color(.background))
    }

    private var navigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }

            Spacer()
        }
        .tint(Color(.icon))
        .padding()
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

    private var imagePadding: EdgeInsets? {
        return modalType.hasNewUpsellScreen ? Self.imagePadding : nil
    }
}

#if swift(>=5.9)
import CombineSchedulers

#Preview("Classic") {
    let scheduler: AnySchedulerOf<DispatchQueue> = .main
    let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(retrievePlans: { plans }, validate: { _ in
        try? await scheduler.sleep(for: .milliseconds((2000...3000).randomElement()!))
    })
    return PlanOptionsView(viewModel: .init(client: client), modalType: .subscription)
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
    return PlanOptionsView(viewModel: .init(client: client), modalType: .subscription)
}

#Preview("Currencies") {
    let plans: [PlanOption] = [
        .init(duration: .twoYears, price: .init(amount: 145, currency: "USD")),
        .init(duration: .oneYear, price: .init(amount: 85, currency: "EUR")),
        .init(duration: .threeMonths, price: .init(amount: 33, currency: "JPY")),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(retrievePlans: { plans }, validate: { _ in () })
    return PlanOptionsView(viewModel: .init(client: client), modalType: .subscription)
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
