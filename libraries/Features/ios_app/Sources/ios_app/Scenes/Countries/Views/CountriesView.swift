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
    let onCountrySelected: (CountryItemViewModel) -> Void
    let onShowSearch: () -> Void
    let onDisplayServicesInfo: () -> Void

    var body: some View {
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
                .disabled(!viewModel.enableViewToggle)
                .accessibilityIdentifier("secureCoreSwitch")
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Color(.background))
            .overlay(
                Rectangle()
                    .fill(Color(uiColor: .normalSeparatorColor()))
                    .frame(height: 1 / UIScreen.main.scale),
                alignment: .bottom
            )

            // Table Content
            CountriesListView(
                viewModel: viewModel,
                onCountrySelected: onCountrySelected
            )
        }
        .background(Color(.background))
        .navigationTitle(Localizable.countries)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onShowSearch) {
                    Image(uiImage: IconProvider.magnifier)
                }
                .accessibilityIdentifier("countrySearchButton")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onDisplayServicesInfo) {
                    Image(uiImage: IconProvider.infoCircle)
                }
            }
        }
    }
}

struct CountriesListView: View {
    @ObservedObject var viewModel: CountriesViewModelObservable
    let onCountrySelected: (CountryItemViewModel) -> Void

    var body: some View {
        List {
            ForEach(0 ..< viewModel.numberOfSections(), id: \.self) { section in
                Section {
                    ForEach(0 ..< viewModel.numberOfRows(in: section), id: \.self) { row in
                        let cellModel = viewModel.cellModel(for: row, in: section)
                        countryCellView(for: cellModel)
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
        .background(Color(.background))
    }

    @ViewBuilder
    private func countryCellView(for cellModel: RowViewModel) -> some View {
        switch cellModel {
        case let .serverGroup(viewModel):
            CountryCellWrapper(viewModel: viewModel)
                .onTapGesture {
                    onCountrySelected(viewModel)
                }

        case let .profile(viewModel):
            DefaultProfileCellWrapper(viewModel: viewModel)

        case let .banner(viewModel):
            BannerView(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

        case let .offerBanner(viewModel):
            OfferBannerView(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
                }
            }
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
    }
}

// MARK: - UIKit Wrapper for CountryCell

struct CountryCellWrapper: UIViewRepresentable {
    let viewModel: CountryItemViewModel

    func makeUIView(context _: Context) -> UITableViewCell {
        let cell = CountryCell()
        cell.viewModel = viewModel
        return cell
    }

    func updateUIView(_ uiView: UITableViewCell, context _: Context) {
        if let cell = uiView as? CountryCell {
            cell.viewModel = viewModel
        }
    }
}

// MARK: - UIKit Wrapper for DefaultProfileTableViewCell

struct DefaultProfileCellWrapper: UIViewRepresentable {
    let viewModel: DefaultProfileViewModel

    func makeUIView(context _: Context) -> DefaultProfileTableViewCell {
        let cell = DefaultProfileTableViewCell()
        cell.viewModel = viewModel
        return cell
    }

    func updateUIView(_ uiView: DefaultProfileTableViewCell, context _: Context) {
        uiView.viewModel = viewModel
    }
}
