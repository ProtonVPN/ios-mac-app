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
import SwiftUI
import Theme

public struct PlanOptionsViewV2TCA: View {
    @Bindable var store: StoreOf<PaymentsFeature>
    @Environment(\.dismiss) var dismiss

    public init(store: StoreOf<PaymentsFeature>) {
        self.store = store
    }

    public var body: some View {
        let upsellModalType = store.upsellModalType
        let showSecondaryButton = !upsellModalType.hasNewUpsellScreen
        Group {
            if case .directSubscriptionManagement = store.presentationKind {
                if store.isDirectSubscriptionReady {
                    DirectSubscriptionManagementView()
                        .background(Color(.background))
                        .safeAreaInset(edge: .top) {
                            navigationBar(title: "Subscriptions")
                        }
                }
            } else {
                PaymentsUpsellBackgroundView(showGradient: true) {
                    VStack {
                        LegacyPaymentsModalBodyView(
                            upsellModalType: upsellModalType,
                            imagePadding: imagePadding,
                            displayBodyFeatures: showSecondaryButton
                        )

                        Spacer()

                        PlanOptionsListViewV2TCA(store: store, showSecondaryButton: showSecondaryButton)
                    }
                    .padding(.horizontal, .themeSpacing16)
                    .padding(.bottom, .themeSpacing8)
                    .safeAreaInset(edge: .top) {
                        if !showSecondaryButton {
                            navigationBar()
                        }
                    }
                    .frame(maxWidth: Dimensions.maxContentWidth)
                }
            }
        }
        .background(Color(.background))
        .task { await store.send(.onAppear).finish() }
        .overlay(purchaseInProgressView)
        .sheet(
            item: $store.scope(
                state: \.destination?.webCheckout,
                action: \.destination.webCheckout
            )
        ) { store in
            PaymentsWebCheckoutView(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private func navigationBar(title: String? = nil) -> some View {
        ZStack {
            if let title {
                Text(title)
                    .font(.headline)
            }
            HStack {
                Button {
                    store.send(.notNowTapped)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                Spacer()
            }
        }
        .tint(Color(.icon))
        .padding()
    }

    @ViewBuilder
    private var purchaseInProgressView: some View {
        if store.isPurchaseInProgress {
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
        store.upsellModalType.hasNewUpsellScreen ? Dimensions.imagePadding : nil
    }

    private enum Dimensions {
        static let imagePadding: EdgeInsets = .init(top: 0, leading: 52, bottom: 24, trailing: 52)
        static let maxContentWidth: CGFloat = 480
    }
}

private struct PaymentsUpsellBackgroundView<Content>: View where Content: View {
    let showGradient: Bool
    @ViewBuilder let content: Content

    init(showGradient: Bool, content: () -> Content) {
        self.showGradient = showGradient
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            if showGradient {
                VStack(spacing: .zero) {
                    gradient
                    Spacer()
                }
                .ignoresSafeArea()
            }
            content
        }
    }

    private var gradient: some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return Color.clear
            .aspectRatio(isPad ? 2 : 1, contentMode: .fit)
            .background(
                ZStack {
                    let gradient = Gradient(colors: [
                        Asset.upsellGradientTop.swiftUIColor,
                        Asset.upsellGradientBottom.swiftUIColor,
                    ])
                    LinearGradient(
                        gradient: gradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(0.4)
                    let fadingGradient = Gradient(colors: [.clear, Color(.background)])
                    LinearGradient(
                        gradient: fadingGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
    }
}

#if DEBUG
    #Preview("Default") {
        PlanOptionsViewV2TCA(
            store: Store(initialState: .init()) {
                PaymentsFeature()
            } withDependencies: {
                $0.paymentsClient = .testValue
            }
        )
    }

    #Preview("Purchase in Progress") {
        PlanOptionsViewV2TCA(
            store: Store(initialState: .previewPurchaseInProgress) {
                PaymentsFeature()
            } withDependencies: {
                $0.paymentsClient = .testValue
            }
        )
    }

    private extension PaymentsFeature.State {
        static var previewPurchaseInProgress: Self {
            var state = Self()
            state.plans = [.oneMonth, .oneYear, .twoYearsWebPlan]
            state.discountByPlanID = [PlanOptionV2.oneYear.id: -33]
            state.selectedPlan = .oneYear
            state.isPurchaseInProgress = true
            return state
        }
    }
#endif
