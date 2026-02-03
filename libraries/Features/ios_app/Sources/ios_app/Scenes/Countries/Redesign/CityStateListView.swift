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
    @Bindable var store: StoreOf<CityStateListFeature>

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
            case let .loaded(.cities(groups)),
                 let .loaded(.states(groups)):
                NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                    VStack(spacing: 0) {
                        header
                        list(groups)
                    }
                    .background(Color(.background))
                } destination: { store in
                    switch store.case {
                    case let .serversList(store):
                        ServersListView(store: store)
                    }
                }
            }
        }
        .background(Color(.background))
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var header: some View {
        HStack {
            CountryToolbarItemView(countryCode: store.countryCode)
                .padding(.top, .themeSpacing16)
            Spacer(minLength: 0)
        }
        .padding([.horizontal, .top], .themeSpacing16)
    }

    private func list(_ groups: [ServerGroupInfo]) -> some View {
        List {
            Section {
                ForEach(groups, id: \.serverOfferingID) { groupInfo in
                    Button {
                        store.send(.navigateTo(groupInfo))
                    } label: {
                        row(groupInfo: groupInfo)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                if let title = store.sectionTitle {
                    Text(title)
                        .foregroundColor(Color(.text, .weak))
                        .themeFont(.body3(emphasised: false))
                }
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: .themeSpacing16, bottom: 0, trailing: .themeSpacing16))
        }
        .listStyle(.plain)
    }

    private func shouldConnect(location: ConnectionSpec.Location) -> Bool {
        if let locationConnected = vpnConnectionStatus.spec?.location, locationConnected == location {
            false
        } else {
            true
        }
    }

    @ViewBuilder
    private func row(groupInfo: ServerGroupInfo) -> some View {
        let location = groupInfo.kind.locationWithOrder()
        let shouldConnect = shouldConnect(location: location)

        HStack(spacing: .themeSpacing12) {
            Group {
                IconProvider.mapPin.swiftUIImage
                    .renderingMode(.template)
                    .foregroundColor(Color(.icon, .weak))
                Text(groupInfo.kind.name)
                    .themeFont(.body1(.regular))
                    .foregroundStyle(Color(.text))
                    .lineLimit(1)
                Spacer(minLength: 0)
                CityStateServerFeaturesView(groupInfo: groupInfo)
                    .foregroundStyle(Color(.icon, .weak))
            }
            .opacity(Double(groupInfo.isUnderMaintenance ? 0.25 : 1))
            Button {
                if groupInfo.isUnderMaintenance {
                    store.send(.serversUnderMaintenance)
                } else if shouldConnect {
                    store.send(.connect(location: location, trigger: .countriesCity))
                } else {
                    store.send(.disconnect)
                }
            } label: {
                ConnectButtonView(
                    isUnderMaintenance: groupInfo.isUnderMaintenance,
                    shouldConnect: shouldConnect
                )
            }
            .buttonStyle(.plain)
        }
        .frame(height: .themeSpacing64)
        .listRowSpacing(0)
    }
}
