//
//  Created on 28/01/2026 by Max Kupetskyi.
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
import CountriesShared
import SwiftUI
import Theme
import UIKit

struct SearchResultsView: View {
    var store: StoreOf<SearchResultsDisplayFeature>

    var body: some View {
        List {
            ForEach(store.rows) { row in
                rowView(for: row)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.background))
    }

    @ViewBuilder
    private func rowView(for row: SearchResultRow) -> some View {
        switch row {
        case let .sectionHeader(title):
            SearchSectionHeaderView(title: title)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(.background))

        case .upsell:
            UpsellBannerView(numberOfCountries: store.numberOfCountries, onUpgrade: { store.send(.showUpsell) })
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

        case let .country(country):
            searchCountryRow(country)
                .listRowInsets(EdgeInsets.zero)
                .listRowBackground(Color(.background))
                .listRowSeparator(.hidden)
                .onTapGesture {
                    store.send(.countrySelected(country))
                }

        case let .city(city):
            searchCityRow(city)
                .listRowInsets(EdgeInsets.zero)
                .listRowBackground(Color(.background))
                .listRowSeparator(.hidden)
                .onTapGesture {
                    store.send(.citySelected(city))
                }

        case let .server(server):
            searchServerRow(server, isSecureCore: false)
                .listRowInsets(EdgeInsets.zero)
                .listRowBackground(Color(.background))
                .listRowSeparator(.hidden)
                .onTapGesture {
                    store.send(.serverSelected(server))
                }

        case let .secureCoreCountry(server):
            searchServerRow(server, isSecureCore: true)
                .listRowInsets(EdgeInsets.zero)
                .listRowBackground(Color(.background))
                .listRowSeparator(.hidden)
                .onTapGesture {
                    store.send(.serverSelected(server))
                }
        }
    }

    private func searchCountryRow(_ country: SearchCountryIndex) -> some View {
        HStack(spacing: .themeSpacing16) {
            if let flag = UIImage.flag(countryCode: country.countryCode) {
                flag.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 20)
                    .cornerRadius(.themeRadius4)
                    .clipped()
            }

            highlightedText(country.name, searchText: store.searchText)
                .foregroundColor(Color(.text))

            Spacer()

            Button(action: {
                store.send(.countrySelected(country))
            }) {
                ConnectButtonView(isUnderMaintenance: false, shouldConnect: true)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                store.send(.countrySelected(country))
            }) {
                Image("ic-chevron-right", bundle: CountriesResources.bundle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(.square(24))
                    .foregroundColor(Color(.icon, .weak))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
        .contentShape(Rectangle())
    }

    private func searchCityRow(_ city: SearchCityIndex) -> some View {
        HStack(spacing: .themeSpacing16) {
            if let flag = ImageAsset.Image.flag(countryCode: city.countryCode) {
                flag.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 20)
                    .cornerRadius(.themeRadius4)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: .themeSpacing2) {
                highlightedText(city.translatedCityName ?? city.cityName, searchText: store.searchText)
                    .foregroundColor(Color(.text))
                Text(city.countryName)
                    .themeFont(.caption())
                    .foregroundColor(Color(.text, .weak))
            }

            Spacer()

            Button(action: {
                store.send(.citySelected(city))
            }) {
                ConnectButtonView(isUnderMaintenance: false, shouldConnect: true)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
        .contentShape(Rectangle())
    }

    private func searchServerRow(_ server: SearchServerIndex, isSecureCore: Bool) -> some View {
        HStack(spacing: .themeSpacing16) {
            Group {
                if isSecureCore {
                    if let entryCountryCode = server.entryCountryCode,
                       let entryFlag = UIImage.flag(countryCode: entryCountryCode) {
                        Image(uiImage: entryFlag)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 20)
                            .cornerRadius(.themeRadius4)
                            .clipped()
                    }
                    if let exitFlag = UIImage.flag(countryCode: server.exitCountryCode) {
                        Image(uiImage: exitFlag)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 20)
                            .cornerRadius(.themeRadius4)
                            .clipped()
                    }
                    highlightedText(server.countryName, searchText: store.searchText)
                        .foregroundColor(Color(.text))
                } else {
                    VStack(alignment: .leading, spacing: .themeSpacing2) {
                        highlightedText(server.serverName, searchText: store.searchText)
                            .foregroundColor(Color(.text))
                        Text(server.translatedCityName ?? server.cityName)
                            .themeFont(.caption())
                            .foregroundColor(Color(.text, .weak))
                    }
                }
            }
            .opacity(server.alphaOfMainElements)

            Spacer()

            HStack(spacing: .themeSpacing12) {
                if !server.underMaintenance, !server.isUsersTierTooLow {
                    HStack(spacing: .themeSpacing4) {
                        Circle()
                            .fill(Color(server.loadColor))
                            .frame(.square(8))
                        Text("\(server.load)%")
                            .themeFont(.caption())
                            .foregroundColor(Color(.text, .weak))
                            .fixedSize()
                    }
                    .fixedSize()
                }

                HStack(spacing: .themeSpacing8) {
                    if server.isP2PAvailable {
                        capabilityIcon("ic-arrows-switch", alpha: server.alphaOfMainElements)
                    }
                    if server.isTorAvailable {
                        capabilityIcon("ic-brand-tor", alpha: server.alphaOfMainElements)
                    }
                    if server.isStreamingAvailable {
                        capabilityIcon("ic-play", alpha: server.alphaOfMainElements)
                    }
                }

                Button(action: {
                    store.send(.serverSelected(server))
                }) {
                    ConnectButtonView(isUnderMaintenance: server.underMaintenance, shouldConnect: true)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
        .contentShape(Rectangle())
    }

    private func capabilityIcon(_ name: String, alpha: Double) -> some View {
        Image(name, bundle: CountriesResources.bundle)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(.square(16))
            .foregroundColor(.white)
            .opacity(alpha)
    }

    private func highlightedText(_ text: String, searchText: String) -> Text {
        guard !searchText.isEmpty else { return Text(text) }
        let parts = text.highlightedParts(searchText: searchText)
        return parts.map { part in
            Text(part.text)
                .foregroundColor(part.isHighlighted ? Color(.background, .interactive) : Color(.text))
        }
        .reduce(Text(""), +)
    }
}

struct SearchSectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .themeFont(.caption(emphasised: true))
            .foregroundColor(Color(.text, .weak))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing8)
            .background(Color(.background))
    }
}

extension String {
    var normalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    func highlightedParts(searchText: String) -> [(text: String, isHighlighted: Bool)] {
        let normalizedSearch = searchText.normalized.lowercased()
        let normalizedSelf = normalized.lowercased()

        guard let range = normalizedSelf.range(of: normalizedSearch) else {
            return [(self, false)]
        }

        let startIndex = index(startIndex, offsetBy: normalizedSelf.distance(from: normalizedSelf.startIndex, to: range.lowerBound))
        let endIndex = index(self.startIndex, offsetBy: normalizedSelf.distance(from: normalizedSelf.startIndex, to: range.upperBound))

        var parts: [(String, Bool)] = []
        if startIndex > self.startIndex {
            parts.append((String(self[self.startIndex ..< startIndex]), false))
        }
        parts.append((String(self[startIndex ..< endIndex]), true))
        if endIndex < self.endIndex {
            parts.append((String(self[endIndex...]), false))
        }
        return parts
    }
}

#if DEBUG
    #Preview("Search Results Mixed") {
        SearchResultsView(
            store: Store(initialState: .previewMixed) {
                SearchResultsDisplayFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
