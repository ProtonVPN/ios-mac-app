//
//  Created on 18/05/2023.
//
//  Copyright (c) 2023 Proton AG
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

import ComposableArchitecture
import SwiftUINavigation

import Strings
import Theme

public struct SettingsView: View {
    typealias DestinationViewStore = ViewStore<SettingsFeature.Destination?, SettingsFeature.Action>

    // Remove default leading indentation and add padding above and below the header
    private let sectionHeaderInsets = EdgeInsets(top: .themeSpacing12, leading: 0, bottom: .themeSpacing12, trailing: 0)

    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    struct ChildFeature {
        let icon: Theme.ImageAsset
        let title: String
        let accessory: Accessory.Style
    }

    let features = (
        netShield: ChildFeature(icon: Theme.Asset.icNetshield, title: Localizable.settingsTitleNetshield, accessory: .disclosure),
        killSwitch: ChildFeature(icon: Theme.Asset.icKillswitch, title: Localizable.settingsTitleKillSwitch, accessory: .disclosure),

        vpnProtocol: ChildFeature(icon: Theme.Asset.icServers, title: Localizable.settingsTitleProtocol, accessory: .disclosure),
        vpnAccelerator: ChildFeature(icon: Theme.Asset.icRocket, title: Localizable.settingsTitleVpnAccelerator, accessory: .disclosure),
        advanced: ChildFeature(icon: Theme.Asset.icSliders, title: Localizable.settingsTitleAdvanced, accessory: .disclosure),

        theme: ChildFeature(icon: Theme.Asset.icCircleHalfFilled, title: Localizable.settingsTitleTheme, accessory: .disclosure),
        betaAccess: ChildFeature(icon: Theme.Asset.icKeySkeleton, title: Localizable.settingsTitleBetaAccess, accessory: .disclosure),
        widget: ChildFeature(icon: Theme.Asset.icGrid2, title: Localizable.settingsTitleWidget, accessory: .disclosure),

        supportCenter: ChildFeature(icon: Theme.Asset.icLifeRing, title: Localizable.settingsTitleSupportCenter, accessory: .externalLink),
        reportAnIssue: ChildFeature(icon: Theme.Asset.icBug, title: Localizable.settingsTitleReportIssue, accessory: .disclosure),
        debugLogs: ChildFeature(icon: Theme.Asset.icCode, title: Localizable.settingsTitleDebugLogs, accessory: .disclosure),

        censorship: ChildFeature(icon: Theme.Asset.icUsers, title: Localizable.settingsTitleCensorship, accessory: .externalLink),
        rateProtonVPN: ChildFeature(icon: Theme.Asset.icStar, title: Localizable.settingsTitleRate, accessory: .disclosure),

        restoreDefault: ChildFeature(icon: Theme.Asset.icArrowRotateRight, title: Localizable.settingsTitleRestoreDefaultSettings, accessory: .none),

        signOut: ChildFeature(icon: Theme.Asset.icArrowInToRectangle, title: Localizable.settingsTitleSignOut, accessory: .none)
    )

    private var content: some View {
        List {
            accountSection
            featuresSection
            connectionSection
            generalSection
            supportSection
            improveProtonSection
            restoreDefaultsSection
            signOutSection
            Section(footer: footerView) { EmptyView() }
        }
        .padding(.top, .themeSpacing16)
        .background(navigationDestinations)
    }

    public var body: some View {
        NavigationView {
            List {
                accountSection
                featuresSection
                connectionSection
                generalSection
                supportSection
                improveProtonSection
                restoreDefaultsSection
                signOutSection
                Section(footer: footerView) { EmptyView() }
            }
            .padding(.top, .themeSpacing16)
            .background(Color(.background, .strong).ignoresSafeArea())
            .background(navigationDestinations) // append invisible navigation destinations to the hierarchy
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle(Localizable.settingsTitle)
        }
        .navigationViewStyle(.stack)
        .hidingScrollBackground
    }

    @ViewBuilder
    private func section(named name: String? = nil, @ViewBuilder content: @escaping () -> some View) -> some View {
        if let name {
            Section(content: content, header: { sectionHeader(named: name) })
                .listRowBackground(Color(.background, .normal))
        } else {
            Section(content: content)
                .listRowBackground(Color(.background, .normal))
        }
        // List row background must be applied to sections instead of at the cell level because navigationlinks wrap the cell in a Z/HStack
    }

    private func sectionHeader(named name: String) -> some View {
        Text(name)
            .themeFont(.body2())
            .foregroundColor(Color(.text, .weak))
            .textCase(nil) // Disable upper-casing section titles (on by default)
            .listRowInsets(sectionHeaderInsets)
    }

    @ViewBuilder
    private var footerView: some View {
        WithViewStore(store, observe: { $0.appVersion }) { viewStore in
            HStack {
                Spacer()
                Text(Localizable.settingsAppVersion(viewStore.state))
                    .themeFont(.caption())
                    .foregroundColor(Color(.text, .weak))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.bottom, .themeSpacing32)
        }
    }

// MARK: Section Views

    private var accountSection: some View {
        section(named: Localizable.settingsSectionTitleAccount) {
            SettingsCell(
                icon: Asset.avatar.swiftUIImage,
                content: .multiline(title: "Eric Norbert", subtitle: "eric.norbert@proton.me"),
                accessory: .disclosure
            )
        }
    }

    private var featuresSection: some View {
        section(named: Localizable.settingsSectionTitleFeatures) {
            WithViewStore(store, observe: { $0.netShield }) { viewStore in
                SettingsCell(feature: features.netShield, value: viewStore.state)
                    .onTapGesture { store.send(.netShieldTapped) }
            }
            WithViewStore(store, observe: { $0.killSwitch }) { viewStore in
                SettingsCell(feature: features.killSwitch, value: viewStore.state)
                    .onTapGesture { store.send(.killSwitchTapped) }
            }
        }
    }

    private var connectionSection: some View {
        section(named: Localizable.settingsSectionTitleConnection) {
            SettingsCell(feature: features.vpnProtocol, value: nil)
            SettingsCell(feature: features.vpnAccelerator, value: NetShieldSettingsFeature.State.on)
            SettingsCell(feature: features.advanced, value: nil)
        }
    }

    private var generalSection: some View {
        section(named: Localizable.settingsSectionTitleGeneral) {
            WithViewStore(store, observe: { $0.theme }) { viewStore in
                SettingsCell(feature: features.theme, value: viewStore.state)
                    .onTapGesture { store.send(.themeTapped) }
            }

            SettingsCell(feature: features.betaAccess, value: nil)
            SettingsCell(feature: features.widget, value: nil)
        }
    }

    private var supportSection: some View {
        section(named: Localizable.settingsSectionTitleSupport) {
            SettingsCell(feature: features.supportCenter, value: nil)
            SettingsCell(feature: features.reportAnIssue, value: nil)
            SettingsCell(feature: features.debugLogs, value: nil)
        }
    }

    private var improveProtonSection: some View {
        section(named: Localizable.settingsSectionTitleImproveProton) {
            SettingsCell(feature: features.censorship, value: nil)
            SettingsCell(feature: features.rateProtonVPN, value: nil)
        }
    }

    private var restoreDefaultsSection: some View {
        section {
            SettingsCell(feature: features.restoreDefault, value: nil)
        }
    }

    private var signOutSection: some View {
        section {
            SettingsCell(feature: features.signOut, value: nil)
        }
    }

    private var footerSection: some View {
        Section(footer: footerView) { EmptyView() }
    }

    // MARK: Navigation Destinations

    /// In the absence of `.navigationDestination`, this is builds a collection of empty and inert NavigationLinks,
    /// which which activate when the destination state matches their case.
    ///
    /// - Note: Links/navigation destinations are implemented separately from the cells that correspond to these
    /// destinations, because wrapping a list element with a `NavigationLink` appends an uncustomisable disclosure
    /// indicator to the trailing edge of each row
    private var navigationDestinations: some View {
        WithViewStore(store, observe: { $0.destination }) { destinationStore in
            featureDestinations(viewStore: destinationStore)
            generalDestinations(viewStore: destinationStore)
        }
    }

    private func destination(
        case: CasePath<SettingsFeature.Destination, Void>,
        view destination: @escaping () -> some View
    ) -> some View {
        return WithViewStore(store, observe: { $0.destination }) { viewStore in
            NavigationLink(
                unwrapping: viewStore.binding(get: { $0 }, send: .dismissDestination),
                case: `case`,
                onNavigate: { _ in },
                destination: { _ in destination() },
                label: { EmptyView() }
            )
        }
    }

    @ViewBuilder private func featureDestinations(viewStore: DestinationViewStore) -> some View {
        destination(case: /.netShield) {
            NetShieldSettingsView(store: store.scope(state: \.netShield, action: SettingsFeature.Action.netShield))
        }
        destination(case: /.killSwitch) {
            KillSwitchSettingsView(store: store.scope(state: \.killSwitch, action: SettingsFeature.Action.killSwitch))
        }
    }

    @ViewBuilder private func generalDestinations(viewStore: DestinationViewStore) -> some View {
        destination(case: /.theme) {
            ThemeSettingsView(store: store.scope(state: \.theme, action: SettingsFeature.Action.theme))
        }
    }
}

extension SettingsCell {
    init(feature: SettingsView.ChildFeature, value: LocalizedStringConvertible?) {
        self.init(
            icon: feature.icon,
            content: .standard(title: feature.title, value: value?.localizedDescription),
            accessory: Accessory(style: feature.accessory)
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: Store(
            initialState: SettingsFeature.State(destination: .none, netShield: .on, killSwitch: .off, theme: .light),
            reducer: SettingsFeature()
        ))
    }
}
