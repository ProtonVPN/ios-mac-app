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

import ConnectionInventory
import Dependencies
import Domain
import LegacyCommon
import Persistence
import ProtonCoreUIFoundations
import SharedViews
import Sharing
import SwiftUI
import Theme
import VPNAppCore

struct CityStateListView: View {
    private let countryCode: String
    private let cities: [String]

    @Environment(\.dismiss) private var dismiss

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus

    init(countryCode: String) {
        @Dependency(\.serverRepository) var repository
        let statesGroups = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: countryCode))],
                groupedBy: .stateName
            )
        let citiesGroups = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: countryCode))],
                groupedBy: .cityName
            )
        let cities = citiesGroups
            .compactMap(\.cityName)
        let states = statesGroups
            .compactMap(\.stateName)
        self.init(countryCode: countryCode, cities: states)
    }

    init(countryCode: String, cities: [String]) {
        self.countryCode = countryCode
        self.cities = cities
    }

    private func connect(location: ConnectionSpec.Location, shouldConnect: Bool) {
        let spec = ConnectionSpec(location: location, features: [])
        Task {
            do {
                if shouldConnect {
                    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage
                    let connectionProtocol = try defaultConnectionStorage.getDefaultProtocol()
                    @Dependency(\.connectToVPN) var connectToVPN
                    try await connectToVPN(spec, connectionProtocol, .countriesCity)
                } else {
                    @Dependency(\.disconnectVPN) var disconnectVPN
                    try await disconnectVPN(.countriesCity)
                }
            } catch {
                let action = shouldConnect ? "connect" : "disconnect"
                log.error("Failed to \(action) to VPN from \(#file) with error: \(error)")
            }
        }
        dismiss()
        DependencyContainer.shared.makeConnectionStatusService().presentStatusViewController()
    }

    @ViewBuilder
    private func cityRow(name: String) -> some View {
        let location: ConnectionSpec.Location = .city(name: name, code: countryCode)
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
        NavigationStack {
            List {
                Section {
                    ForEach(cities, id: \.self) { city in
                        NavigationLink {
                            ServersListView(countryCode: countryCode, city: city)
                        } label: {
                            cityRow(name: city)
                        }
                    }
                } header: {
                    Text("Cities (\(cities.count))") // extract to localizable
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
                    CountryToolbarItemView(countryCode: countryCode)
                }
            }
        }
        .background(Color(.background))
    }
}

private extension ServerGroupInfo {
    var cityName: String? {
        guard case let .city(name, _) = kind else { return nil }
        return name
    }

    var stateName: String? {
        guard case let .state(name, _) = kind else { return nil }
        return name
    }
}

#Preview {
    CityStateListView(countryCode: "PL", cities: ["Warsaw", "Kraków"])
        .colorScheme(.dark)
}
