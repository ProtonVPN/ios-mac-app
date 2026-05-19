//
//  Created on 19/05/2026 by Chris Janusiewicz.
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

import ComposableArchitecture
import SettingsShared
import SwiftUI
import Theme

struct NetworkConfigurationsDebugView: View {
    @Binding var store: StoreOf<NetworkConfigurationsDebugFeature>

    var body: some View {
        content
            .navigationTitle("VPN Configurations")
            .refreshable { store.send(.loadConfigurations) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.addConfigurationTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert(
                "Add Configuration",
                isPresented: Binding(
                    get: { store.prompt != nil },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.prompt(.dismiss))
                        }
                    }
                )
            ) {
                TextField("Bundle identifier", text: $store.newBundleIdentifier)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Cancel", role: .cancel) { store.send(.prompt(.presented(.cancel))) }
                Button("Add") { store.send(.prompt(.presented(.confirm))) }
            } message: {
                Text("Enter the provider bundle identifier for the new VPN configuration.")
            }
            .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var content: some View {
        switch store.content {
        case .none:
            ProgressView()
                .task { store.send(.loadConfigurations) }

        case .loading:
            ProgressView()

        case let .loaded(configurations) where configurations.isEmpty:
            VStack(alignment: .center, spacing: 20) {
                Image(systemName: "tray")
                Text("No installed VPN configurations.")
            }

        case let .loaded(configurations):
            VStack {
                Form {
                    ForEach(configurations) { configuration in
                        section(for: configuration)
                    }
                }
            }

        case let .failed(error):
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .multilineTextAlignment(.center)
                }.padding(.horizontal, 100)
            }
        }
    }

    private func section(for configuration: NetworkConfigurationInfo) -> some View {
        Section(header: Text(configuration.title)) {
            CopyableCell(title: "Kind", value: configuration.kind.rawValue)
            CopyableCell(title: "Enabled", value: "\(configuration.isEnabled)")
            CopyableCell(title: "On-Demand", value: "\(configuration.isOnDemandEnabled)")
            CopyableCell(title: "Status", value: configuration.status)
            if let connectedDate = configuration.connectedDate {
                CopyableCell(title: "Connected", value: connectedDate.formatted())
            }
            if let serverAddress = configuration.serverAddress, !serverAddress.isEmpty {
                CopyableCell(title: "Server", value: serverAddress)
            }
            if let bundleIdentifier = configuration.providerBundleIdentifier {
                CopyableCell(title: "Provider Bundle ID", value: bundleIdentifier)
            }

            if !configuration.providerConfiguration.isEmpty {
                DisclosureGroup("Provider Configuration") {
                    ForEach(configuration.providerConfiguration) { entry in
                        CopyableCell(entry)
                    }
                }
            }

            if !configuration.onDemandRules.isEmpty {
                DisclosureGroup("On-Demand Rules (\(configuration.onDemandRules.count))") {
                    ForEach(Array(configuration.onDemandRules.enumerated()), id: \.offset) { _, rule in
                        Text(rule)
                    }
                }
            }
        }
    }
}
