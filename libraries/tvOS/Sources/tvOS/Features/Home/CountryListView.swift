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

    static let cellSpacing: Double = 20

    static private let columnCount = 6

    static private let gridItem = GridItem(.fixed(250), spacing: cellSpacing)
    private let columns = Array(repeating: gridItem, count: columnCount)

    var body: some View {
        VStack(spacing: .themeSpacing24) {
            Spacer()

            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(Array(store.sections.enumerated()), id: \.element) { sectionIndex, section in
                        Section(content: {
                            ForEach(Array(section.items.enumerated()), id: \.element) { index, item in

                                Button(action: {
                                    store.send(.selectItem(item))
                                    print(item)
                                }, label: {
                                    CountryListItemView(
                                        item: item,
                                        isFocused: focusedIndex == ItemCoordinate(section: sectionIndex, item: index)
                                    )
                                    .opacity(calculateOpacity(forCoordinate: ItemCoordinate(section: sectionIndex, item: index)))
                                })
                                .buttonStyle(CountryListButtonStyle())
                                .padding(.top, .themeSpacing8)
                                .padding(.bottom, .themeSpacing32)
                                .focused($focusedIndex, equals: ItemCoordinate(section: sectionIndex, item: index))

                            }
                        }, header: {
                            CountryListSectionHeaderView(name: section.name)
                        }
                        )
                    }
                }
            }
            .scrollClipDisabled()
            .frame(maxWidth: Constants.maxPreferredContentViewWidth)
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    /// By default we highlight the first row
    static private var lastFocusedIndex = ItemCoordinate(section: 0, item: 0)

    /// We "highlight" current row by making it fully opaque, while other rows and
    /// sections are half transparent.
    private func calculateOpacity(forCoordinate coordinate: ItemCoordinate) -> Double {
        // Always highlight as least one row
        let focused = focusedIndex ?? Self.lastFocusedIndex
        Self.lastFocusedIndex = focused

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

struct CountryListButtonStyle: ButtonStyle {
    // Without this style `hoverEffect` adds colored background which we don't need
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
    }
}
