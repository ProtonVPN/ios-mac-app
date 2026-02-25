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
import Strings
import Theme
import VPNAppCore

struct ServersListView: View {
    @Bindable var store: StoreOf<ServersListFeature>

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus

    @Environment(\.dismiss) private var dismiss
    @State var showingFeaturesInfo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            loadingList
        }
        .background(Color(.background))
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showingFeaturesInfo) {
            ServersFeaturesInformationView(
                viewModel: ServersFeaturesInformationViewModelImplementation.servicesInfo,
                onDismiss: {
                    showingFeaturesInfo = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var loadingList: some View {
        switch store.list {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    store.send(.didAppear)
                }
        case let .loaded(servers):
            list(servers)
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                IconProvider.chevronLeft.swiftUIImage
            }
            .buttonStyle(.plain)

            switch store.listType {
            case let .city(name):
                ServerToolbarItemView(kind: .city(name: name, code: store.countryCode))
                    .padding(.top, .themeSpacing16)
            case let .state(name):
                ServerToolbarItemView(kind: .state(name: name, code: store.countryCode))
                    .padding(.top, .themeSpacing16)
            }
            Spacer(minLength: 0)
        }
        .padding([.horizontal, .top], .themeSpacing16)
    }

    private func list(_ servers: [ServerInfo]) -> some View {
        List {
            Section {
                ForEach(servers, id: \.logical.id) { server in
                    serverRow(server: server)
                }
            } header: {
                sectionHeader
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: .themeSpacing16, bottom: 0, trailing: .themeSpacing16))
        }
        .listStyle(.plain)
    }

    private var sectionHeader: some View {
        HStack {
            Text(Localizable.searchServers)
                .foregroundColor(Color(.text, .weak))
                .themeFont(.body3(emphasised: false))
            Spacer()
            Button {
                showingFeaturesInfo.toggle()
            } label: {
                HStack(spacing: .themeSpacing4) {
                    Text(Localizable.connectionDetailsInfoButton)
                        .themeFont(.body3(emphasised: true))
                        .foregroundStyle(Color(.text, .weak))
                    IconProvider.infoCircle.swiftUIImage.resizable().frame(.square(.themeSpacing16))
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func serverRow(server: ServerInfo) -> some View {
        HStack(spacing: .themeSpacing12) {
            Text(server.logical.name)
                .themeFont(.body1(.regular))
                .foregroundStyle(Color(.text, server.logical.isUnderMaintenance ? .disabled : .normal))
            Spacer(minLength: 0)
            CityStateServerFeaturesView(server: server)
                .foregroundStyle(Color(.icon, server.logical.isUnderMaintenance ? .disabled : .weak))

            connectButton(server)
        }
        .frame(height: .themeSpacing64)
        .listRowSpacing(0)
    }

    @ViewBuilder
    private func connectButton(_ server: ServerInfo) -> some View {
        let location: ConnectionSpec.Location = .exact(
            .paid,
            logicalID: server.logical.id,
            number: server.logical.serverNameComponents.sequence,
            subregion: store.listType.name, // state or city name
            regionCode: store.countryCode
        )
        let shouldConnect = !vpnConnectionStatus.isConnectedTo(location)
        Button {
            if server.logical.isUnderMaintenance {
                store.send(.serversUnderMaintenance)
            } else if shouldConnect {
                store.send(.connect(location: location))
            } else {
                store.send(.disconnect)
            }
        } label: {
            ConnectButtonView(
                isUnderMaintenance: server.logical.isUnderMaintenance,
                shouldConnect: shouldConnect
            )
        }
        .buttonStyle(.plain)
    }
}

private extension VPNConnectionStatus {
    func isConnectedTo(_ location: ConnectionSpec.Location) -> Bool {
        if let locationConnected = spec?.location {
            return locationConnected == location
        }
        return false
    }
}
