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

import Dependencies
import Sharing

import Domain
import Persistence
import ProtonCoreUIFoundations
import SharedViews
import Theme
import VPNAppCore

struct ServersListView: View {
    let countryCode: String
    let city: String
    let servers: [ServerInfo]

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus

    @Environment(\.dismiss) private var dismiss

    init(countryCode: String, city: String) {
        self.countryCode = countryCode
        self.city = city
        @Dependency(\.serverRepository) var repository
        self.servers = repository.getServers(
            filteredBy: [.kind(.city(name: city, code: countryCode))],
            orderedBy: .loadAscending
        )
    }

    private func connect(location: ConnectionSpec.Location, shouldConnect: Bool) {
        let spec = ConnectionSpec(location: location, features: [])
        Task {
            do {
                if shouldConnect {
                    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage
                    let connectionProtocol = try defaultConnectionStorage.getDefaultProtocol()
                    @Dependency(\.connectToVPN) var connectToVPN
                    try await connectToVPN(spec, connectionProtocol, .countriesServer)
                } else {
                    @Dependency(\.disconnectVPN) var disconnectVPN
                    try await disconnectVPN(.countriesServer)
                }
            } catch {
                let action = shouldConnect ? "connect" : "disconnect"
                log.error("Failed to \(action) to VPN from \(#file) with error: \(error)")
            }
        }
        dismiss() // we're two levels deep here, so need to dismiss twice...
        dismiss() // in TCA, we should just dismiss the whole feature?
        DependencyContainer.shared.makeConnectionStatusService().presentStatusViewController()
    }

    @ViewBuilder
    private func serverRow(server: ServerInfo) -> some View {
        let location: ConnectionSpec.Location = .exact(
            .paid,
            logicalID: nil,
            number: server.logical.serverNameComponents.sequence,
            subregion: city,
            regionCode: countryCode
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
                connect(location: location, shouldConnect: shouldConnect)
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

    var body: some View {
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
        .background(Color(.background))
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    IconProvider.chevronLeft.swiftUIImage
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarLeading) {
                ServerToolbarItemView(city: city, countryCode: countryCode)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

private extension ServerGroupInfo {
    var serverName: String? {
        guard case let .city(name, _) = kind else { return nil }
        return name
    }
}

struct ServerToolbarItemView: View {
    let countryCode: String
    let city: String

    let location: ConnectionSpec.Location

    init(city: String, countryCode: String) {
        self.city = city
        self.countryCode = countryCode
        self.location = .city(name: city, code: countryCode)
    }

    var body: some View {
        LocationFeatureView(
            model: .init(
                flag: .country(code: countryCode),
                header: .init(
                    title: location.headerText(locale: .current) ?? countryCode,
                    showConnectedPin: false
                ),
                subheader: .textual(.withoutFeatures(location: city))
            ),
            attachedLeadingView: nil
        )
        .padding(.top, .themeSpacing16)
    }
}
