//
//  Created on 2025-12-24 by Pawel Jurczyk.
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

import SwiftUI

import ComposableArchitecture
import Dependencies
import Sharing

import Domain
import Persistence
import ProtonCoreUIFoundations
import SharedViews
import Theme
import VPNAppCore

struct ServersListView: View {
    var store: StoreOf<ServersListFeature>

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus

    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    IconProvider.chevronLeft.swiftUIImage
                }
                .buttonStyle(.plain)
                ServerToolbarItemView(city: store.listType.name, countryCode: store.countryCode)
                Spacer(minLength: 0)
            }
            .padding([.horizontal, .top], .themeSpacing16)
            Group {
                switch store.list {
                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            store.send(.didAppear)
                        }
                case let .loaded(servers):
                    list(servers: servers)
                }
            }
        }
        .background(Color(.background))
        .navigationBarBackButtonHidden()
    }

    private func list(servers: [ServerInfo]) -> some View {
        List {
            Section {
                ForEach(servers, id: \.logical.id) { server in
                    serverRow(server: server)
                }
            } header: {
                Text("Servers (\(servers.count))") // extract to localizable
                    .foregroundColor(Color(.text, .weak))
                    .themeFont(.body3(emphasised: false))
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: .themeSpacing16, bottom: 0, trailing: .themeSpacing16))
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func serverRow(server: ServerInfo) -> some View {
        let location: ConnectionSpec.Location = .exact(
            .paid,
            logicalID: server.logical.id,
            number: server.logical.serverNameComponents.sequence,
            subregion: store.listType.name, // state or city name
            regionCode: store.countryCode
        )
        let shouldConnect =
            if let locationConnected = vpnConnectionStatus.spec?.location,
            locationConnected == location {
                false
            } else {
                true
            }
        HStack(spacing: .themeSpacing12) {
            IconProvider.mapPin.swiftUIImage.renderingMode(.template).foregroundColor(Color(.icon, .weak))
            Text(server.logical.name)
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

private extension ServerGroupInfo {
    var serverName: String? {
        guard case let .city(name, _) = kind else { return nil }
        return name
    }
}
