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

import CombineSchedulers
import ModalsServices
import ModalsShared
import SharedViews
import Strings
import SwiftUI

@MainActor
struct PlanOptionsListView: View {
    @ObservedObject var viewModel: PlanOptionsListViewModel

    let showSecondaryButton: Bool

    private var showHeader: Bool { viewModel.plans.count > 1 }

    init(viewModel: PlanOptionsListViewModel, showSecondaryButton: Bool = false) {
        self.viewModel = viewModel
        self.showSecondaryButton = showSecondaryButton
    }

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

    private func footerView(text: String) -> some View {
        Text(text)
            .themeFont(.body2(emphasised: false))
            .foregroundColor(Color(.text, .weak))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var loadingView: some View {
        PlanOptionView(state: .loading)
    }

    private func discount(option: PlanOption) -> Int? {
        viewModel.availableDiscount(comparedTo: option)
    }

    private var contentView: some View {
        VStack(spacing: .themeSpacing16) {
            ForEach(viewModel.plans, id: \.self) { option in
                if viewModel.isLoading {
                    loadingView
                } else {
                    let isSelected: Bool = viewModel.selectedPlan == option
                    let discount: Int? = discount(option: option)
                    PlanOptionView(state: .loaded(option: option, isSelected: isSelected, discount: discount))
                        .onTapGesture {
                            withAnimation { viewModel.selectedPlan = option }
                        }
                }
            }
            if let renewalText = viewModel.renewalTextForSelectedPlan {
                footerView(text: renewalText)
            }
        }
    }

    private var shouldDisableValidateButton: Bool {
        viewModel.selectedPlan == nil
    }

    private var buttonsView: some View {
        VStack(spacing: .themeSpacing8) {
            AsyncButton {
                await viewModel.validate()
            } label: {
                Text(Localizable.upsellPlansListValidateButton)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(shouldDisableValidateButton)

            if showSecondaryButton {
                Button {
                    viewModel.notNow()
                } label: {
                    Text(Localizable.modalsUpsellStayFree)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

#if DEBUG
    #Preview("Classic") {
        let plans: [PlanOption] = [.oneYear, .oneMonth]
        let client: PlansClient = .init(retrievePlans: { plans }, validate: { _ in () }, availableDiscount: { _ in 55 }, notNow: { _ in })
        let viewModel = PlanOptionsListViewModel(client: client)
        return PlanOptionsListView(viewModel: viewModel)
    }

    #Preview("Loading") {
        let scheduler: AnySchedulerOf<DispatchQueue> = .main
        let plans: [PlanOption] = [.twoYearsWebPlan, .oneYear, .oneMonth]
        let client: PlansClient = .init(
            retrievePlans: {
                try? await scheduler.sleep(for: .milliseconds((500 ... 2000).randomElement()!))
                return plans
            },
            validate: { _ in
                try? await scheduler.sleep(for: .milliseconds((2000 ... 3000).randomElement()!))
            },
            availableDiscount: { _ in
                33
            },
            notNow: { _ in }
        )
        let viewModel = PlanOptionsListViewModel(client: client)
        return PlanOptionsListView(viewModel: viewModel)
    }
#endif
