//
//  Created on 23/12/2025 by Max Kupetskyi.
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

import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

struct CountriesView: View {
    @State private var secureCoreOn = false
    @State private var enableViewToggle = true
    @State private var navigationPath: [NavigationDestination] = []
    @State private var showingFeaturesInfo = false
    @State private var showingGatewayInfo = false
    @State private var showingStreamingInfo = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Secure Core Bar
                HStack {
                    Text(Localizable.useSecureCore)
                        .foregroundColor(Color(.text))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("", isOn: Binding(
                        get: { secureCoreOn },
                        set: { newValue in
                            secureCoreOn = newValue
                            print("Secure Core toggled: \(newValue)")
                        }
                    ))
                    .tint(Color(uiColor: .brandColor()))
                    .disabled(!enableViewToggle)
                    .accessibilityIdentifier("secureCoreSwitch")
                }
                .padding(.horizontal, .themeSpacing16)
                .frame(height: 50)
                .background(Color(uiColor: .backgroundColor()))

                Divider()
                    .background(Color(uiColor: .normalSeparatorColor()))

                // Table Content
                CountriesListView(
                    navigationPath: $navigationPath
                )
            }
            .background(Color(uiColor: .backgroundColor()))
            .navigationTitle(Localizable.countries)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(uiColor: .backgroundColor()), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        print("Features info button tapped")
                        showingFeaturesInfo = true
                    }) {
                        Image(uiImage: IconProvider.infoCircle)
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        print("Search button tapped")
                        navigationPath.append(.search)
                    }) {
                        Image(uiImage: IconProvider.magnifier)
                            .foregroundColor(.white)
                    }
                    .accessibilityIdentifier("countrySearchButton")
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .sheet(isPresented: $showingFeaturesInfo) {
                Text("Features Information")
                    .padding()
            }
            .sheet(isPresented: $showingGatewayInfo) {
                Text("Gateway Information")
                    .padding()
            }
            .sheet(isPresented: $showingStreamingInfo) {
                Text("Streaming Information")
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .search:
            SearchViewWrapper(
                secureCoreOn: secureCoreOn,
                userTier: "free",
                searchData: [],
                navigationPath: $navigationPath
            )
            .navigationTitle(Localizable.searchTitle)
            .navigationBarTitleDisplayMode(.inline)
        case let .country(countryName):
            CountryView(
                countryName: countryName,
                servers: [
                    MockServer(name: "Server 1"),
                    MockServer(name: "Server 2"),
                    MockServer(name: "Server 3"),
                ],
                showServerHeaders: true,
                streamingAvailable: true
            )
        }
    }
}
