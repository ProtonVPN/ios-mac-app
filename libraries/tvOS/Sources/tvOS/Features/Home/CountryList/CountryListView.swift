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

    static let columnCount = 6
    static private let gridItemWidth: Double = 210
    static private let unfocusedOpacity: Double = 0.5 // "Unfocused" items are half transparent

    let columns: [GridItem]

    init(store: StoreOf<CountryListFeature>, contentAllowedWidth: Double) {
        self.store = store
        self.columns = Self.columns(availableWidth: contentAllowedWidth)
    }

    private static func columns(availableWidth: Double) -> [GridItem] {
        let spacerCount = Double(Self.columnCount) - 1
        let totalGridItemWidth = Double(Self.columnCount) * Self.gridItemWidth
        let totalSpacing = availableWidth - totalGridItemWidth
        let singleSpacing = totalSpacing / spacerCount
        let gridItem = GridItem(.fixed(Self.gridItemWidth), spacing: singleSpacing)
        return Array(repeating: gridItem, count: Self.columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns) {
            Section {
                itemList(items: store.recommendedSection.items, sectionIndex: 0)
            } header: {
                CountryListSectionHeaderView(name: store.recommendedSection.name)
                    .opacity((focusedIndex?.section ?? 0) == 0 ? 1 : Self.unfocusedOpacity)
            }

            Section {
                itemList(items: store.countriesSection.items, sectionIndex: 1)
            } header: {
                CountryListSectionHeaderView(name: store.countriesSection.name)
                    .opacity(focusedIndex?.section == 1 ? 1 : Self.unfocusedOpacity)
            }
        }
    }

    @ViewBuilder
    func itemList(items: [CountryListItem], sectionIndex: Int) -> some View {
        ForEach(items) { item in
            let coordinate = ItemCoordinate(section: sectionIndex, item: item)
            Button {
                store.send(.selectItem(item))
            } label: {
                CountryListItemView(
                    item: item,
                    isFocused: focusedIndex?.item == item // this only affects the country name and connected label
                )
                .opacity(opacity(forCoordinate: coordinate))
            }
            .buttonStyle(CountryListButtonStyle())
            .padding(.top, .themeSpacing8)
            .padding(.bottom, .themeSpacing32)
            .focused($focusedIndex, equals: coordinate)
        }
    }

    /// We "highlight" current row by making it fully opaque, while other rows and
    /// sections are half transparent.
    private func opacity(forCoordinate coordinate: ItemCoordinate) -> Double {
        guard let focused = focusedIndex else {
            if coordinate.section == 0 && coordinate.row == 0 {
                return 1 // by default highlight the recommended section
            }
            return Self.unfocusedOpacity
        }

        return focused.row == coordinate.row && focused.section == coordinate.section ? 1 : Self.unfocusedOpacity
    }

    private struct ItemCoordinate: Hashable {
        let section: Int
        let item: CountryListItem
        let row: Int

        init(section: Int, item: CountryListItem) {
            self.section = section
            self.item = item
            self.row = item.row
        }
    }
}

fileprivate struct CountryListButtonStyle: ButtonStyle {
    // Without this style `hoverEffect` adds colored background which we don't need
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
    }
}
