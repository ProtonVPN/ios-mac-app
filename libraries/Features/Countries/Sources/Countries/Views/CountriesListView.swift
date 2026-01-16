//
//  Created on 16/01/2026 by Max Kupetskyi.
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

import ProtonCoreUIFoundations
import SwiftUI
import Theme

struct CountriesListView: View {
    @Binding var navigationPath: [NavigationDestination]

    // Mock data
    let mockCountries = ["United States", "United Kingdom", "Germany", "France", "Japan"]

    var body: some View {
        List {
            Section {
                // Mock banner
                BannerView(bannerType: .upsell)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(uiColor: .backgroundColor()))
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                // Mock offer banner
                OfferBannerView(
                    imageURL: URL(string: "https://example.com/offer.png")!,
                    showCountdown: true
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color(uiColor: .backgroundColor()))
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                // Mock country rows
                ForEach(mockCountries, id: \.self) { country in
                    Text(country)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(uiColor: .backgroundColor()))
                        .listRowInsets(.zero)
                        .onTapGesture {
                            print("Country selected: \(country)")
                            navigationPath.append(.country(country))
                        }
                }
            } header: {
                ServersHeaderSwiftUIView(
                    title: "Countries",
                    callback: {
                        print("Header info button tapped")
                    }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .backgroundColor()))
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
