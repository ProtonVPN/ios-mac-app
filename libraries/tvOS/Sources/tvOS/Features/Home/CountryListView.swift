//
//  Created on 08/05/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import SwiftUI
import ProtonCoreUIFoundations
import Theme
import ComposableArchitecture

/// Displays the list of countries (and other connectable items, like "fastest").
struct CountryListView: View {

    @Bindable var store: StoreOf<CountryListFeature>

    let columns = [
        GridItem(.fixed(250), spacing: 20),
        GridItem(.fixed(250), spacing: 20),
        GridItem(.fixed(250), spacing: 20),
        GridItem(.fixed(250), spacing: 20),
        GridItem(.fixed(250), spacing: 20),
        GridItem(.fixed(250), spacing: 20),
    ]

    var body: some View {
        VStack(spacing: .themeSpacing24) {
            Spacer()

            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(store.sections) { section in
                        Section(section.name) {
                            ForEach(section.items) { item in

                                Button(action: {
                                    print(item)
                                }, label: {
                                    HomeListItemView(item: item)
                                })
                                .buttonStyle(CountryListButtonStyle())
                                .padding([.top], 20)

                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
            .frame(maxWidth: 800)
            .task {
                store.send(.updateList)
                store.send(.loadLogicals)
            }
        }
    }
}

struct HomeListItemView: View {
    let item: HomeListItem

    var body: some View {
        VStack {
            SimpleFlagView(regionCode: item.code, flagSize: .tvListSize)
            Text(item.name)
                .font(.body)
                .padding([.top], 34)
                .padding([.bottom], 0)

            HStack(spacing: 14.4) {
                Text(item.isConnected ? "Connected" : "")
                    .font(.caption)
                    .foregroundStyle(Asset.vpnGreen.swiftUIColor)
                if item.isConnected {
                    ConnectedCircleView()
                }
            }
            .padding([.top], 16)
            .padding([.bottom], 49)
        }
    }
}

struct CountryListButtonStyle: ButtonStyle {

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .hoverEffect(.highlight)
  }

}

//#Preview {
//    CountryListView()
//}
