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
                        ServersListView(store: store, onDismiss: onDismiss)
                    }
                }
            }
        }
        .background(Color(.background))
    }

    private var header: some View {
        HStack {
            CountryToolbarItemView(countryCode: store.countryCode)
            Spacer(minLength: 0)
        }
        .padding([.horizontal, .top], .themeSpacing16)
    }

    private func list(_ groups: [ServerGroupInfo]) -> some View {
        List {
            Section {
                ForEach(groups, id: \.serverOfferingID) { groupInfo in
                    NavigationLink(state: pathState(groupInfo: groupInfo)) {
                        row(groupInfo: groupInfo)
                    }
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

    private func pathState(groupInfo: ServerGroupInfo) -> CityStateListFeature.Path.State? {
        switch groupInfo.kind {
        case let .city(name, code):
            .serversList(.init(countryCode: code, listType: .city(name)))
        case let .state(name, code):
            .serversList(.init(countryCode: code, listType: .state(name)))
        default:
            nil
        }
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
        let location = groupInfo.kind.location
        let shouldConnect = shouldConnect(location: location)

        HStack(spacing: .themeSpacing12) {
            IconProvider.mapPin.swiftUIImage.renderingMode(.template).foregroundColor(Color(.icon, .weak))
            Text(groupInfo.kind.name)
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

private extension ServerGroupInfo.Kind {
    var location: ConnectionSpec.Location {
        switch self {
        case let .city(name, code):
            .city(name: name, code: code)
        case let .state(name, code):
            .state(name: name, code: code)
        case let .country(code):
            .country(code: code)
        case let .gateway(name):
            .gateway(name: name)
        }
    }

    var name: String {
        switch self {
        case let .city(name, _), let .state(name, _):
            name
        default:
            ""
        }
    }
}
