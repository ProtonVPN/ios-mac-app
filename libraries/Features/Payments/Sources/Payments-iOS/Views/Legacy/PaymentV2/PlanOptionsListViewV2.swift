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

import CombineSchedulers
import PaymentsShared
import SharedViews
import Strings
import SwiftUI

@MainActor
struct PlanOptionsListViewV2: View {
    @ObservedObject var viewModel: PlanOptionsListViewModelV2

    let showSecondaryButton: Bool

    private var showHeader: Bool { viewModel.plans.count > 1 }

    init(viewModel: PlanOptionsListViewModelV2, showSecondaryButton: Bool = false) {
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
        PlanOptionViewV2(state: .loading)
    }

    private func discount(option: PlanOptionV2) -> Int? {
        viewModel.availableDiscount(comparedTo: option)
    }

    private var contentView: some View {
        VStack(spacing: .themeSpacing16) {
            ForEach(viewModel.plans, id: \.id) { option in
                if viewModel.isLoading {
                    loadingView
                } else {
                    let isSelected: Bool = viewModel.selectedPlan == option
                    let discount: Int? = discount(option: option)
                    PlanOptionViewV2(state: .loaded(option: option, isSelected: isSelected, discount: discount))
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
        let plans: [PlanOptionV2] = [.oneYear, .oneMonth]
        let client: PlansClientV2 = .init(retrievePlans: { plans }, validate: { _ in }, availableDiscount: { _ in 55 }, notNow: { _ in })
        let viewModel = PlanOptionsListViewModelV2(client: client)
        return PlanOptionsListViewV2(viewModel: viewModel)
    }

    #Preview("Loading") {
        let scheduler: AnySchedulerOf<DispatchQueue> = .main
        let plans: [PlanOptionV2] = [.twoYearsWebPlan, .oneYear, .oneMonth]
        let client: PlansClientV2 = .init(
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
        let viewModel = PlanOptionsListViewModelV2(client: client)
        return PlanOptionsListViewV2(viewModel: viewModel)
    }
#endif
