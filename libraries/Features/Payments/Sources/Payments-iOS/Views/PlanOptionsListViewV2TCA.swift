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

import ComposableArchitecture
import PaymentsShared
import SharedViews
import Strings
import SwiftUI
import Theme

@MainActor
struct PlanOptionsListViewV2TCA: View {
    @Bindable var store: StoreOf<PaymentsFeature>
    let showSecondaryButton: Bool

    private var showHeader: Bool {
        store.plans.count > 1
    }

    init(store: StoreOf<PaymentsFeature>, showSecondaryButton: Bool = true) {
        self.store = store
        self.showSecondaryButton = showSecondaryButton
    }

    var body: some View {
        VStack(spacing: .themeSpacing16) {
            if showHeader {
                Text(Localizable.upsellPlansListSectionHeader)
                    .themeFont(.body2(emphasised: false))
                    .foregroundColor(Color(.text, .weak))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: .themeSpacing12) {
                if store.isLoading {
                    PlanOptionViewV2TCA(state: .loading)
                } else {
                    VStack(spacing: .themeSpacing16) {
                        ForEach(store.plans, id: \.id) { option in
                            let isSelected = store.selectedPlan == option
                            PlanOptionViewV2TCA(
                                state: .loaded(
                                    option: option,
                                    isSelected: isSelected,
                                    discount: store.discountByPlanID[option.id]
                                )
                            )
                            .onTapGesture {
                                store.send(.selectedPlanChanged(option), animation: .default)
                            }
                        }

                        if let renewal = store.renewalTextForSelectedPlan {
                            Text(renewal)
                                .themeFont(.body2(emphasised: false))
                                .foregroundColor(Color(.text, .weak))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            buttonsView
        }
    }

    private var buttonsView: some View {
        VStack(spacing: .themeSpacing8) {
            AsyncButton {
                await store.send(.validateTapped).finish()
            } label: {
                Text(Localizable.upsellPlansListValidateButton)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.selectedPlan == nil)

            if showSecondaryButton {
                Button {
                    store.send(.notNowTapped)
                } label: {
                    Text(Localizable.modalsUpsellStayFree)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

#if DEBUG
    #Preview("Loading") {
        PlanOptionsListViewV2TCA(
            store: Store(
                initialState: .previewLoading
            ) {
                PaymentsFeature()
            }
        )
        .padding()
    }

    #Preview("Loaded") {
        PlanOptionsListViewV2TCA(
            store: Store(
                initialState: .previewLoaded
            ) {
                PaymentsFeature()
            }
        )
        .padding()
    }

    private extension PaymentsFeature.State {
        static var previewLoading: Self {
            var state = Self()
            state.isLoading = true
            return state
        }

        static var previewLoaded: Self {
            var state = Self()
            state.plans = [.oneMonth, .oneYear, .twoYearsWebPlan]
            state.discountByPlanID = [PlanOptionV2.oneYear.id: -33]
            state.selectedPlan = .oneYear
            return state
        }
    }
#endif
