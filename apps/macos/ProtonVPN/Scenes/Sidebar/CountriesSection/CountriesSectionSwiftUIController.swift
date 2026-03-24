//
//  Created on 27/03/2026 by Max Kupetskyi.
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

import AppKit
import ComposableArchitecture
import Countries
import Domain
import Ergonomics
import LegacyCommon
import Modals
import NetShield
import Payments
import Strings
import SwiftUI
import Theme
import VPNShared

final class CountriesSectionViewController: NSHostingController<CountriesSectionRootView> {
    required init(store: StoreOf<CountriesSectionFeature>) {
        super.init(rootView: CountriesSectionRootView(store: store, quickSettingsStore: store.scope(state: \.quickSettings, action: \.quickSettings)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    override func loadView() {
        super.loadView()
        // The sidebar embeds child controller views with Auto Layout constraints.
        // Prevent NSHostingView from generating autoresizing-mask constraints.
        view.translatesAutoresizingMaskIntoConstraints = false
    }
}

struct CountriesSectionRootView: View {
    @Bindable var store: StoreOf<CountriesSectionFeature>
    @Bindable var quickSettingsStore: StoreOf<QuickSettingsFeature>

    private var countriesStore: StoreOf<CountriesListFeature> {
        store.scope(state: \.countriesList, action: \.countriesList)
    }

    private func isDetailPresented(for type: QuickSettingType) -> Binding<Bool> {
        Binding(
            get: { quickSettingsStore.activeType == type },
            set: { if !$0 { quickSettingsStore.send(.dismissDetails) } }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                quickSettingsRow(availableWidth: proxy.size.width)
                searchBar.padding(.horizontal, .themeSpacing20).padding(.top, .themeSpacing8)
                CountriesListView(store: countriesStore).padding(.top, .themeSpacing8)
            }
            .background(Color(.background, .weak))
            .quickSettingsSheets(store: $quickSettingsStore)
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private func quickSettingsRow(availableWidth: CGFloat) -> some View {
        let visibleTypes: [QuickSettingType] = QuickSettingType.allCases.filter { type in
            switch type {
            case .netShieldDisplay: quickSettingsStore.netShield.isVisible
            case .portForwardingDisplay: quickSettingsStore.portForwarding.isVisible
            default: true
            }
        }

        return HStack(spacing: 0) {
            ForEach(visibleTypes, id: \.self) { type in
                quickSettingsButtonCell {
                    QuickSettingButtonView(type: type, store: quickSettingsStore)
                        .overlay(alignment: .topTrailing) {
                            if type == .netShieldDisplay, quickSettingsStore.netShieldBadgeVisible {
                                netShieldBadge
                                    .allowsHitTesting(false)
                            }
                        }
                        .popover(
                            isPresented: isDetailPresented(for: type),
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .top
                        ) {
                            quickSettingDetailPopover(availableWidth: availableWidth)
                        }
                }
            }
        }
        .frame(height: Dimensions.quickSettingsRowHeight)
        .padding(.horizontal, .themeSpacing12)
        .padding(.top, .themeSpacing8)
        .accessibilityLabel(Localizable.quickSettingsTitle)
        .alert($quickSettingsStore.scope(state: \.alert, action: \.alert))
    }

    private var netShieldBadge: some View {
        Text(quickSettingsStore.netShieldBadgeText)
            .themeFont(.footnote(emphasised: true))
            .foregroundStyle(quickSettingsStore.netShieldBadgeModel.enabled ? .white : Color(.text, .hint))
            .padding(.horizontal, .themeSpacing6)
            .frame(minWidth: Dimensions.quickSettingsBadgeMinWidth, minHeight: Dimensions.quickSettingsBadgeMinHeight)
            .background(RoundedRectangle(cornerRadius: .themeSpacing4).fill(Color(.background)))
            .padding([.top, .trailing], .themeSpacing6)
    }

    @ViewBuilder
    private func quickSettingDetailPopover(availableWidth: CGFloat) -> some View {
        if let detailStore = quickSettingsStore.scope(
            state: \.destination?.quickSettingDetail,
            action: \.destination.quickSettingDetail
        ) {
            QuickSettingDetailView(store: detailStore)
                .frame(width: availableWidth)
                .background(Color(.background))
        }
    }

    private func quickSettingsButtonCell(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, .themeSpacing8)
            .padding(.top, .themeSpacing4)
            .padding(.bottom, .themeSpacing12)
            .frame(maxWidth: .infinity, minHeight: Dimensions.quickSettingsButtonCellHeight, maxHeight: Dimensions.quickSettingsButtonCellHeight)
    }

    private var searchBar: some View {
        HStack(spacing: .themeSpacing8) {
            Theme.Asset.Icons.magnifier.swiftUIImage
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color(.icon, .hint))
                .frame(.square(Dimensions.iconSize))

            TextField(
                Localizable.searchForCountry,
                text: Binding(
                    get: { countriesStore.searchText },
                    set: { countriesStore.send(.searchText($0)) }
                )
            )
            .textFieldStyle(.plain)
            .font(.title3(emphasised: false))
            .disabled(quickSettingsStore.isSearchDisabled)
            .accessibilityIdentifier("SearchTextField")

            if !countriesStore.searchText.isEmpty {
                Button(action: { countriesStore.send(.searchText("")) }) {
                    Theme.Asset.Icons.crossCircleFilled.swiftUIImage
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(Color(.icon, .hint))
                        .frame(.square(Dimensions.iconSize))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ClearSearchButton")
            }
        }
        .padding(.horizontal, .themeSpacing8)
        .frame(height: Dimensions.searchBarHeight)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                .fill(Color(.background, .weak))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                        .stroke(Color(.border), lineWidth: Dimensions.searchBarBorderWidth)
                )
        )
    }
}

private struct QuickSettingsSheetsModifier: ViewModifier {
    @Bindable var store: StoreOf<QuickSettingsFeature>

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.scope(state: \.destination?.upsell, action: \.destination.upsell)) { store in
                UpsellViewController(
                    modalType: store.modalType,
                    upgradeAction: { store.send(.upgradeTapped) },
                    continueAction: { store.send(.continueTapped) }
                )
                .frame(width: Dimensions.sheetWidth, height: Dimensions.sheetHeight)
                .background(Color(.background))
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.discourageSecureCoreView,
                    action: \.destination.discourageSecureCoreView
                )
            ) { store in
                DiscourageSecureCoreView(store: store)
                    .frame(minWidth: Dimensions.sheetWidth, minHeight: Dimensions.sheetHeight)
            }
    }

    private enum Dimensions {
        static let sheetWidth: CGFloat = 520
        static let sheetHeight: CGFloat = 590
    }
}

private extension View {
    func quickSettingsSheets(store: Bindable<StoreOf<QuickSettingsFeature>>) -> some View {
        modifier(QuickSettingsSheetsModifier(store: store.wrappedValue))
    }
}

private extension CountriesSectionRootView {
    enum Dimensions {
        static let iconSize: CGFloat = 16

        static let quickSettingsRowHeight: CGFloat = 54
        static let quickSettingsBadgeMinWidth: CGFloat = 20
        static let quickSettingsBadgeMinHeight: CGFloat = 14
        static let quickSettingsButtonCellHeight: CGFloat = 54

        static let searchBarHeight: CGFloat = 46
        static let searchBarBorderWidth: CGFloat = 1
    }
}
