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
import Dependencies
import Domain
import LegacyCommon
import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import Search
import Strings
import SwiftUI
import UIKit

struct CountriesView: View {
    @ObservedObject var viewModel: CountriesViewModelObservable

    @State private var selectedCountry: CountryItemViewModel?
    @State private var showingFeaturesInfo = false
    @State private var showingStreamingInfo: (CountryItemViewModel, [VpnStreamingOption])? = nil
    @State private var showingSearch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Secure Core Bar
                HStack {
                    Text(Localizable.useSecureCore)
                        .foregroundColor(Color(.text))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("", isOn: Binding(
                        get: { viewModel.secureCoreOn },
                        set: { newValue in
                            viewModel.toggleState(toOn: newValue)
                        }
                    ))
                    .tint(Color(uiColor: .brandColor()))
                    .disabled(!viewModel.enableViewToggle)
                    .accessibilityIdentifier("secureCoreSwitch")
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(uiColor: .backgroundColor()))
                .overlay(
                    Rectangle()
                        .fill(Color(uiColor: .normalSeparatorColor()))
                        .frame(height: 1 / UIScreen.main.scale),
                    alignment: .bottom
                )

                // Table Content
                CountriesListView(
                    viewModel: viewModel,
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
                        showingSearch = true
                    }) {
                        Image(uiImage: IconProvider.magnifier)
                            .foregroundColor(.white)
                    }
                    .accessibilityIdentifier("countrySearchButton")
                }
            }
            .navigationDestination(item: $selectedCountry) { country in
                CountryView(
                    viewModel: country,
                    onDisplayStreamingServices: {
                        showingStreamingInfo = (country, country.streamingServices)
                    }
                )
            }
            .sheet(isPresented: $showingFeaturesInfo) {
                ServersFeaturesInformationView(
                    viewModel: ServersFeaturesInformationViewModelImplementation.servicesInfo,
                    onDismiss: {
                        showingFeaturesInfo = false
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
            .sheet(isPresented: $showingSearch) {
                // TODO: Integrate Search view when migrated to SwiftUI
                Text("Search - To be implemented")
            }
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
    @ObservedObject var viewModel: CountriesViewModelObservable
    @Binding var selectedCountry: CountryItemViewModel?

    var body: some View {
        List {
            ForEach(0 ..< viewModel.numberOfSections(), id: \.self) { section in
                Section {
                    ForEach(0 ..< viewModel.numberOfRows(in: section), id: \.self) { row in
                        let cellModel = viewModel.cellModel(for: row, in: section)
                        countryCellView(for: cellModel)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(uiColor: .backgroundColor()))
                    }
                } header: {
                    if viewModel.numberOfSections() >= 2,
                       let title = viewModel.titleFor(section: section) {
                        ServersHeaderSwiftUIView(
                            title: title,
                            callback: viewModel.callback(forSection: section)
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
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .onTapGesture {
                    handleCountrySelection(viewModel)
                }

        case let .profile(viewModel):
            DefaultProfileRow(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

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
        selectedCountry = country
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
                }
            }
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
    }
}
