//
//  Created on 2025-12-23 by Pawel Jurczyk.
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

import ComposableArchitecture
import ConnectionInventory
import Dependencies
import Domain
import LegacyCommon
import ProtonCoreUIFoundations
import SharedViews
import Sharing
import SwiftUI
import Theme
import VPNAppCore

struct CityStateListView: View {
    var store: StoreOf<CityStateListFeature>

    let onDismiss: () -> Void

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus

    var body: some View {
        Group {
            switch store.listState {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { store.send(.didAppear) }
            case let .loaded(type):
                NavigationStackStore(store.scope(state: \.path, action: \.path)) {
                    list(listType: type)
                } destination: { state in
                    switch state {
                    case .serversList:
                        CaseLet(
                            /CityStateListFeature.Path.State.serversList,
                            action: CityStateListFeature.Path.Action.serversList,
                            then: { ServersListView(store: $0, onDismiss: onDismiss) }
                        )
                    }
                }
            }
        }
        .background(Color(.background))
    }

    private func list(listType: CityStateListType) -> some View {
        VStack {
            HStack {
                CountryToolbarItemView(countryCode: store.countryCode)
                Spacer(minLength: 0)
            }
            .padding([.horizontal, .top], .themeSpacing16)
            List {
                Section {
                    switch listType {
                    case let .cities(cities):
                        ForEach(cities, id: \.self) { name in
                            NavigationLink(state: state(listType: .city(name))) {
                                row(name: name, location: .city(name: name, code: store.countryCode))
                            }
                        }
                    case let .states(states):
                        ForEach(states, id: \.self) { name in
                            NavigationLink(state: state(listType: .state(name))) {
                                row(name: name, location: .state(name: name, code: store.countryCode))
                            }
                        }
                    }
                } header: {
                    Text(store.sectionTitle)
                        .foregroundColor(Color(.text, .weak))
                        .themeFont(.body3(emphasised: false))
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden)
                .listRowInsets(.init(top: 0, leading: .themeSpacing16, bottom: 0, trailing: .themeSpacing16))
            }
            .listStyle(.plain)
        }
        .background(Color(.background))
    }

    private func state(listType: ServersListFeature.State.ListType) -> CityStateListFeature.Path.State {
        .serversList(.init(countryCode: store.countryCode, listType: listType))
    }

    @ViewBuilder
    private func row(name: String, location: ConnectionSpec.Location) -> some View {
        let shouldConnect =
            if let locationConnected = vpnConnectionStatus.spec?.location,
            locationConnected == location {
                false
            } else {
                true
            }
        HStack(spacing: .themeSpacing12) {
            IconProvider.mapPin.swiftUIImage.renderingMode(.template).foregroundColor(Color(.icon, .weak))
            Text(name)
            Spacer(minLength: 0)
            Button {
                if shouldConnect {
                    store.send(.connect(location: location))
                    onDismiss()
                } else {
                    store.send(.disconnect)
                }
            } label: {
                ZStack {
                    let style: AppTheme.Style = shouldConnect ? [.interactive, .weak] : [.interactive]
                    Circle().foregroundStyle(Color(.background, style))
                        .frame(.square(40))
                    IconProvider.powerOff.swiftUIImage
                }
            }
            .buttonStyle(.plain)
        }
        .frame(height: .themeSpacing64)
        .listRowSpacing(0)
    }
}
