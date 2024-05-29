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

    // Watch which item is focused to highlight selected row
    @FocusState private var focusedIndex: ItemCoordinate?

    // "Unfocused" items are half transparent
    private let unfocusedOpacity: Double = 0.5

    static private let cellSpacing: Double = 20

    static private let columnCount = 6
    let columns = Array.init(repeating: GridItem(.fixed(250), spacing: cellSpacing), count: columnCount)

    var body: some View {
        VStack(spacing: .themeSpacing24) {
            Spacer()

            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(Array(store.sections.enumerated()), id: \.element) { sectionIndex, section in
                        Section(content: {
                            ForEach(Array(section.items.enumerated()), id: \.element) { index, item in

                                Button(action: {
                                    print(item)
                                }, label: {
                                    HomeListItemView(
                                        item: item,
                                        isFocused: focusedIndex == ItemCoordinate(section: sectionIndex, item: index)
                                    )
                                    .opacity(calculateOpacity(forCoordinate: ItemCoordinate(section: sectionIndex, item: index)))
                                })
                                .buttonStyle(CountryListButtonStyle())
                                .padding([.top], .themeSpacing24)
                                .focused($focusedIndex, equals: ItemCoordinate(section: sectionIndex, item: index))

                            }
                        }, header: {
                            VStack(alignment: .leading) {
                                Text(section.name)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding([.leading], CountryListView.cellSpacing)

                            }
                        }
                        )
                    }
                }
            }
            .scrollClipDisabled()
            .frame(maxWidth: Constants.maxPreferredContentViewWidth)
            .task {
                store.send(.updateList)
                store.send(.loadLogicals)
            }
        }
    }

    /// We "highlight" current row by making it fully opaque, while other rows and
    /// sections are half transparent.
    private func calculateOpacity(forCoordinate coordinate: ItemCoordinate) -> Double {
        // Nothing is focused, so everything is opaque
        guard let focused = focusedIndex else {
            return 1
        }
        // We are not in the same section, so half transparent
        guard focused.section == coordinate.section else {
            return unfocusedOpacity
        }

        // Only show current row in full opacity
        if focused.row == coordinate.row {
            return 1
        }

        return unfocusedOpacity
    }

    private struct ItemCoordinate: Hashable {
        let section: Int
        let item: Int

        let columnCount = 6

        var row: Int {
            return (item - (item % columnCount)) / columnCount
        }
    }
}

struct HomeListItemView: View {
    let item: HomeListItem
    let isFocused: Bool

    private let normalScale = CGSize(width: 1, height: 1)
    private let focusedScale = CGSize(width: 1.3, height: 1.3)

    var body: some View {
        VStack {
            SimpleFlagView(regionCode: item.code, flagSize: .tvListSize)
                .hoverEffect(.highlight)

                Text(item.name)
                    .font(.body)
                    .padding([.top], 34)
                    .padding([.bottom], 0)
                    .scaleEffect(isFocused ? focusedScale : normalScale)
                    // This is not ideally 1:1 the same as ".hoverEffect(.highlight)",
                    // but the best I could find.
                    .animation(.easeInOut(duration: 0.1), value: isFocused)

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
    // Without this style `hoverEffect` adds colored background which we don't need
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
    }
}
