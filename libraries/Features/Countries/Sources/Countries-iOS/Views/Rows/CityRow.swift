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

import CountriesShared
import SwiftUI
import Theme
import UIKit

struct CityRow: View {
    let city: CityFeature.State
    let searchText: String?

    var body: some View {
        HStack(spacing: .themeSpacing12) {
            // Flag and city/country name
            HStack(spacing: .themeSpacing16) {
                if let flagImage = city.countryFlag {
                    Image(uiImage: flagImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 20)
                        .cornerRadius(.themeRadius4)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: .themeSpacing2) {
                    // City name
                    if let searchText, !searchText.isEmpty {
                        highlightedText(city.displayName, searchText: searchText)
                    } else {
                        Text(city.displayName)
                            .foregroundColor(Color(.text))
                    }

                    // Country name
                    Text(city.countryName)
                        .themeFont(.caption())
                        .foregroundColor(Color(.text)).opacity(0.6)
                }
            }

            Spacer()

            // Connect button
            if let text = city.textInPlaceOfConnectIcon {
                Text(text)
                    .themeFont(.caption())
                    .foregroundColor(Color(.text))
            } else {
                Button(action: {
                    print("Connect to \(city.displayName)") // TODO: connect to connection
                }) {
                    city.connectIcon
                        .swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                        .padding(.themeSpacing8)
                        .background(city.connectButtonColor)
                        .cornerRadius(.themeRadius16)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func highlightedText(_ text: String, searchText: String) -> some View {
        let parts = text.highlightedParts(searchText: searchText)
        parts.map { part in
            Text(part.text)
                .foregroundColor(part.isHighlighted ? Color(uiColor: .brandColor()) : Color(.text))
        }.reduce(Text(""), +)
    }
}
