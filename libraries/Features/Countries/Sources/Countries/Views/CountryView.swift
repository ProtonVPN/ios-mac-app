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

import ComposableArchitecture
import ProtonCoreUIFoundations
import Search
import SwiftUI
import Theme
import UIKit

struct CountryView: View {
    var store: StoreOf<CountryFeature>

    let countryName: String = "United States"
    let servers: [MockServer] = []
    let showServerHeaders: Bool = true
    let streamingAvailable: Bool = true

    var body: some View {
        List {
            ForEach(0 ..< servers.count, id: \.self) { index in
                Section {
                    Text(servers[index].name)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(.zero)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(uiColor: .backgroundColor()))
                        .onTapGesture {
                            print("Server tapped: \(servers[index].name)")
                        }
                } header: {
                    if showServerHeaders {
                        serverHeader(for: index)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .backgroundColor()))
        .navigationTitle(countryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(uiColor: .backgroundColor()), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func serverHeader(for sectionIndex: Int) -> some View {
        let title = "Server Group \(sectionIndex + 1)"
        let hasStreamingCallback = streamingAvailable && sectionIndex == 0

        HStack {
            Text(title)
                .themeFont(.body2(emphasised: true))
                .foregroundColor(Color(.text, .weak))

            Spacer()

            if hasStreamingCallback {
                Button(action: {
                    print("Streaming info requested for section \(sectionIndex)")
                }) {
                    Image(uiImage: IconProvider.infoCircle)
                        .foregroundColor(Color(uiColor: .iconNorm()))
                }
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
        .frame(height: Dimensions.countriesHeaderHeight)
    }

    enum Dimensions {
        static let countriesHeaderHeight: CGFloat = 40
    }
}

struct MockServer: Identifiable {
    let id = UUID()
    let name: String
}
