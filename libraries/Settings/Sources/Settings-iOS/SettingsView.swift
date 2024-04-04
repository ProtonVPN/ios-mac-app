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

import Localization
import Settings
import Strings
import Theme
import ProtonCoreUIFoundations

public struct SettingsView: View {
    typealias DestinationViewStore = ViewStore<SettingsFeature.Destination?, SettingsFeature.Action>

    // Remove default leading indentation and add padding above and below the header
    private let sectionHeaderInsets = EdgeInsets(top: .themeSpacing12, leading: 0, bottom: .themeSpacing12, trailing: 0)

    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    struct ChildFeature {
        let icon: Image
        let title: String
        let accessory: Accessory.Style
    }

    private func makeCell(
        for feature: SettingsView.ChildFeature,
        value: LocalizedStringConvertible?,
        action: SettingsFeature.Action? = nil
    ) -> SettingsCell {
        SettingsCell(
            icon: feature.icon,
            content: .standard(title: feature.title, value: value?.localizedDescription),
            accessory: Accessory(style: feature.accessory),
            onTap: { if let action { store.send(action) } }
        )
    }

    let features = (
        netShield: ChildFeature(icon: Theme.Asset.icNetshield.swiftUIImage, title: Localizable.settingsTitleNetshield, accessory: .disclosure),
        killSwitch: ChildFeature(icon: Theme.Asset.icKillswitch.swiftUIImage, title: Localizable.settingsTitleKillSwitch, accessory: .disclosure),

        vpnProtocol: ChildFeature(icon: IconProvider.servers, title: Localizable.settingsTitleProtocol, accessory: .disclosure),
        vpnAccelerator: ChildFeature(icon: IconProvider.rocket, title: Localizable.settingsTitleVpnAccelerator, accessory: .disclosure),
        advanced: ChildFeature(icon: IconProvider.sliders, title: Localizable.settingsTitleAdvanced, accessory: .disclosure),

        theme: ChildFeature(icon: IconProvider.circleHalfFilled, title: Localizable.settingsTitleTheme, accessory: .disclosure),
        betaAccess: ChildFeature(icon: IconProvider.keySkeleton, title: Localizable.settingsTitleBetaAccess, accessory: .disclosure),
        widget: ChildFeature(icon: IconProvider.grid2, title: Localizable.settingsTitleWidget, accessory: .disclosure),

        supportCenter: ChildFeature(icon: IconProvider.lifeRing, title: Localizable.settingsTitleSupportCenter, accessory: .externalLink),
        reportAnIssue: ChildFeature(icon: IconProvider.bug, title: Localizable.settingsTitleReportIssue, accessory: .disclosure),
        debugLogs: ChildFeature(icon: IconProvider.code, title: Localizable.settingsTitleDebugLogs, accessory: .disclosure),

        censorship: ChildFeature(icon: IconProvider.users, title: Localizable.settingsTitleCensorship, accessory: .externalLink),
        rateProtonVPN: ChildFeature(icon: IconProvider.star, title: Localizable.settingsTitleRate, accessory: .disclosure),

        restoreDefault: ChildFeature(icon: IconProvider.arrowRotateRight, title: Localizable.settingsTitleRestoreDefaultSettings, accessory: .none),

        signOut: ChildFeature(icon: IconProvider.arrowInToRectangle, title: Localizable.settingsTitleSignOut, accessory: .none)
    )

    public var body: some View {
        NavigationView {
            List {
                listOffsetView // Adding top padding to the List itself breaks navigation title animations
                accountSection
                featuresSection
                connectionSection
                generalSection
                supportSection
                improveProtonSection
                restoreDefaultsSection
                signOutSection
                Section(footer: footerView, content: { EmptyView() })
            }
            .hidingScrollBackground
            .background(Color(.background, .strong).ignoresSafeArea())
            .background(navigationDestinations) // append invisible navigation destinations to the hierarchy
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle(Localizable.settingsTitle)
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private func section(named name: String? = nil, @ViewBuilder content: @escaping () -> some View) -> some View {
        if let name {
            Section(content: content, header: { sectionHeader(named: name) })
        } else {
            Section(content: content)
        }
    }

    private func sectionHeader(named name: String) -> some View {
        Text(name)
            .themeFont(.body2())
            .foregroundColor(Color(.text, .weak))
            .textCase(nil) // Disable upper-casing section titles (on by default)
            .listRowInsets(sectionHeaderInsets)
    }

    private var listOffsetView: some View {
        Section(footer: Spacer(), content: { EmptyView() })
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
                makeCell(for: features.netShield, value: viewStore.state, action: .netShieldTapped)
            }
            WithViewStore(store, observe: { $0.killSwitch }) { viewStore in
                makeCell(for: features.killSwitch, value: viewStore.state, action: .killSwitchTapped)
            }
        }
    }

    private var connectionSection: some View {
        section(named: Localizable.settingsSectionTitleConnection) {
            WithViewStore(store, observe: \.protocol) { viewStore in
                makeCell(for: features.vpnProtocol, value: viewStore.protocol, action: .protocolTapped)
            }
            makeCell(for: features.vpnAccelerator, value: NetShieldSettingsFeature.State.on)
            makeCell(for: features.advanced, value: nil)
        }
    }

    private var generalSection: some View {
        section(named: Localizable.settingsSectionTitleGeneral) {
            WithViewStore(store, observe: { $0.theme }) { viewStore in
                makeCell(for: features.theme, value: viewStore.state, action: .themeTapped)
            }
            makeCell(for: features.betaAccess, value: nil)
            makeCell(for: features.widget, value: nil)
        }
    }

    private var supportSection: some View {
        section(named: Localizable.settingsSectionTitleSupport) {
            makeCell(for: features.supportCenter, value: nil)
            makeCell(for: features.reportAnIssue, value: nil)
            makeCell(for: features.debugLogs, value: nil)
        }
    }

    private var improveProtonSection: some View {
        section(named: Localizable.settingsSectionTitleImproveProton) {
            makeCell(for: features.censorship, value: nil)
            makeCell(for: features.rateProtonVPN, value: nil)
        }
    }

    private var restoreDefaultsSection: some View {
        section {
            makeCell(for: features.restoreDefault, value: nil)
        }
    }

    private var signOutSection: some View {
        section {
            makeCell(for: features.signOut, value: nil)
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
            connectionDestinations(viewStore: destinationStore)
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

    @ViewBuilder private func connectionDestinations(viewStore: DestinationViewStore) -> some View {
        destination(case: /.protocol) {
            ProtocolSettingsView(store: store.scope(state: \.protocol, action: SettingsFeature.Action.protocol))
        }
    }

    @ViewBuilder private func generalDestinations(viewStore: DestinationViewStore) -> some View {
        destination(case: /.theme) {
            ThemeSettingsView(store: store.scope(state: \.theme, action: SettingsFeature.Action.theme))
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: Store(
            initialState: SettingsFeature.State(
                destination: .none,
                netShield: .on,
                killSwitch: .off,
                protocol: .init(protocol: .smartProtocol, vpnConnectionStatus: .disconnected, reconnectionAlert: nil),
                theme: .light
            ),
            reducer: { SettingsFeature() }
        ))
    }
}
