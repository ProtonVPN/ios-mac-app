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
import SharedViews
import Strings

struct PlanOptionsListView: View {
    @ObservedObject var viewModel: PlanOptionsListViewModel

    private var showHeader: Bool { viewModel.plansCount > 1 }

    var body: some View {
        VStack(spacing: .themeSpacing16) {
            if showHeader {
                headerView
            }

            VStack(spacing: .themeSpacing12) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    contentView
                }
            }

            buttonsView
        }
        .task {
            await viewModel.onAppear()
        }
    }

    private var headerView: some View {
        Text(Localizable.upsellPlansListSectionHeader)
            .themeFont(.body2(emphasised: false))
            .foregroundColor(Color(.text, .weak))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingView: some View {
        ForEach(0..<viewModel.plansCount, id: \.self) { _ in
            PlanOptionView(planOption: .loading, isLoading: true, isSelected: false)
        }
    }

    private var contentView: some View {
        ForEach(viewModel.plans, id: \.self) { option in
            let isSelected: Bool = viewModel.selectedPlan == option
            PlanOptionView(planOption: option, isLoading: viewModel.isLoading, isSelected: isSelected)
                .onTapGesture {
                    withAnimation { viewModel.selectedPlan = option }
                }
        }
    }

    private var buttonsView: some View {
        VStack(spacing: .themeSpacing8) {
            Button(action: viewModel.validate) {
                Text(Localizable.upsellPlansListValidateButton)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.selectedPlan == nil)

            Button(action: viewModel.notNow) {
                Text(Localizable.modalsUpsellStayFree)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

#if swift(>=5.9)
#Preview("Classic") {
    let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF", discount: 35)),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(plansCount: { plans.count }, retrievePlans: { plans })
    let viewModel = PlanOptionsListViewModel(client: client)
    return PlanOptionsListView(viewModel: viewModel)
}

#Preview("Loading") {
    let scheduler: AnySchedulerOf<DispatchQueue> = .main
    let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF", discount: 35)),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    let client: PlansClient = .init(plansCount: { plans.count }, retrievePlans: {
        try? await scheduler.sleep(for: .milliseconds((500...2000).randomElement()!))
        return plans
    })
    let viewModel = PlanOptionsListViewModel(client: client)
    return PlanOptionsListView(viewModel: viewModel)
}
#else
struct PlanOptionsListView_Provider: PreviewProvider {
    static let scheduler: AnySchedulerOf<DispatchQueue> = .main
    static let plans: [PlanOption] = [
        .init(duration: .oneYear, price: .init(amount: 85, currency: "CHF", discount: 35)),
        .init(duration: .oneMonth, price: .init(amount: 11, currency: "CHF"))
    ]
    static let client: PlansClient = .init(plansCount: { plans.count }, retrievePlans: { plans })
    static let loadingClient: PlansClient = .init(plansCount: { plans.count }, retrievePlans: {
        try? await scheduler.sleep(for: .milliseconds((500...2000).randomElement()!))
        return plans
    })
    static let viewModel = PlanOptionsListViewModel(client: client)
    static let loadingViewModel = PlanOptionsListViewModel(client: loadingClient)

    static var previews: some View {
        PlanOptionsListView(viewModel: viewModel)
            .previewDisplayName("Classic")
        PlanOptionsListView(viewModel: loadingViewModel)
            .previewDisplayName("Loading")
        PlanOptionsListView(viewModel: viewModel)
            .previewDisplayName("iPad")
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
    }
}
#endif
