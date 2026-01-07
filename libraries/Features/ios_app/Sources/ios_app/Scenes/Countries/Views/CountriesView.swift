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

import Announcement
import CommonNetworking
import ComposableArchitecture
import Dependencies
import Domain
import LegacyCommon
import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import Search
import Strings
import SwiftUI
import Theme
import UIKit

struct CountriesView: View {
    var viewModel: CountriesViewModel

    @State private var navigationPath: [NavigationDestination] = []
    @State private var showingFeaturesInfo = false
    @State private var selectedCountry: String?
    @State private var showingStreamingInfo: (CountryItemViewModel, [VpnStreamingOption])? = nil

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Secure Core Bar
                HStack {
                    Text(Localizable.useSecureCore)
                        .foregroundColor(Color(.text))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("", isOn: Binding(
                        get: { viewModel.secureCoreOn },
                        set: { newValue in
                            viewModel.toggleState(toOn: newValue) { _ in }
                        }
                    ))
                    .tint(Color(uiColor: .brandColor()))
                    .disabled(!viewModel.enableViewToggle)
                    .accessibilityIdentifier("secureCoreSwitch")
                }
                .padding(.horizontal, .themeSpacing16)
                .frame(height: 50)
                .background(Color(uiColor: .backgroundColor()))

                Divider()
                    .background(Color(uiColor: .normalSeparatorColor()))

                // Table Content
                CountriesListView(
                    viewModel: viewModel,
                    navigationPath: $navigationPath,
                    selectedCountry: $selectedCountry
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
                        showingFeaturesInfo = true
                    }) {
                        Image(uiImage: IconProvider.infoCircle)
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
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
            .sheet(item: $selectedCountry, id: \.self) { code in
                let state: CityStateListFeature.State = .init(countryCode: code)
                let store: StoreOf<CityStateListFeature> = .init(initialState: state, reducer: CityStateListFeature.init)
                CityStateListView(store: store, onDismiss: { selectedCountry = nil })
                    .presentationDetents([.medium, .large])
                    .presentationContentInteraction(.scrolls)
            }
            .sheet(isPresented: $showingFeaturesInfo) {
                ServersFeaturesInformationView(
                    viewModel: ServersFeaturesInformationViewModelImplementation.servicesInfo,
                    onDismiss: {
                        showingFeaturesInfo = false
                    }
                )
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showGatewayInfo },
                set: { viewModel.showGatewayInfo = $0 }
            )) {
                ServersFeaturesInformationView(
                    viewModel: ServersFeaturesInformationViewModelImplementation.gatewaysInfo,
                    onDismiss: {
                        viewModel.showGatewayInfo = false
                    }
                )
            }
            .sheet(item: Binding(
                get: { showingStreamingInfo.map { StreamingInfoWrapper(country: $0.0, services: $0.1) } },
                set: { showingStreamingInfo = $0.map { ($0.country, $0.services) } }
            )) { wrapper in
                ServersStreamingFeaturesView(
                    viewModel: ServersStreamingFeaturesViewModelImplementation(
                        country: wrapper.country.countryName,
                        streamServices: wrapper.services
                    ),
                    onDismiss: {
                        showingStreamingInfo = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .search:
            SearchViewWrapper(
                viewModel: viewModel,
                navigationPath: $navigationPath
            )
            .navigationTitle(Localizable.searchTitle)
            .navigationBarTitleDisplayMode(.inline)
        case let .country(countryViewModel):
            CountryView(
                viewModel: countryViewModel,
                onDisplayStreamingServices: {
                    showingStreamingInfo = (countryViewModel, countryViewModel.streamingServices)
                }
            )
        }
    }
}

// Helper wrapper for sheet presentation
struct StreamingInfoWrapper: Identifiable {
    let id = UUID()
    let country: CountryItemViewModel
    let services: [VpnStreamingOption]
}

struct CountriesListView: View {
    var viewModel: CountriesViewModel
    @Binding var navigationPath: [NavigationDestination]
    @Binding var selectedCountry: String?

    var body: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.rows.indices, id: \.self) { index in
                        let cellModel = section.rows[index]
                        countryCellView(for: cellModel)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(uiColor: .backgroundColor()))
                            .listRowInsets(.zero)
                    }
                } header: {
                    if viewModel.sections.count >= 2,
                       let title = section.title {
                        ServersHeaderSwiftUIView(
                            title: title,
                            callback: section.callback
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .backgroundColor()))
    }

    @ViewBuilder
    private func countryCellView(for cellModel: RowViewModel) -> some View {
        switch cellModel {
        case let .serverGroup(viewModel):
            CountryRow(viewModel: viewModel, searchText: nil)
                .listRowInsets(.zero)
                .onTapGesture {
                    handleCountrySelection(viewModel)
                }

        case let .profile(viewModel):
            DefaultProfileRow(viewModel: viewModel)
                .listRowInsets(.zero)

        case let .banner(viewModel):
            BannerView(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

        case let .offerBanner(viewModel):
            OfferBannerView(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    private func handleCountrySelection(_ country: CountryItemViewModel) {
        if country.isUsersTierTooLow {
            viewModel.presentUpsell(forCountryCode: country.countryCode)
            return
        }
        if viewModel.secureCoreOn { // not yet supported in the cities/servers view
            navigationPath.append(.country(country))
        } else {
            selectedCountry = country.countryCode
        }
    }
}

// MARK: - SwiftUI ServersHeader

struct ServersHeaderSwiftUIView: View {
    let title: String
    let callback: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .themeFont(.body2(emphasised: false))
                .foregroundColor(Color(.text, .weak))

            Spacer()

            if let callback {
                Button(action: callback) {
                    Image(uiImage: IconProvider.infoCircle)
                        .foregroundColor(Color(uiColor: .iconNorm()))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
    }
}

extension EdgeInsets {
    static let zero = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}
