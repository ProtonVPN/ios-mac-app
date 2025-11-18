//
//  Created on 25/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

import ComposableArchitecture
import UIKit

@Reducer
public struct WhatsNewCheckerFeature {
    @ObservableState
    public struct State: Equatable {
        fileprivate(set) var items: [WhatsNew.Item] = []
    }

    public enum Action {
        case register
        case check
        case show(items: [WhatsNew.Item])
    }

    @Dependency(\.date.now) private var now
    @Shared(.whatsNew) private var whatsNewData

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .register:
                state.items = WhatsNew.Item.allCases
                updateWhatsNewData(for: state.items)
                return .none
            case .check:
                return .run { [items = state.items] send in
                    let evaluatedItems = WhatsNew.Evaluator.evaluate(items: items)
                    if !evaluatedItems.isEmpty {
                        await send(.show(items: evaluatedItems))
                    }
                }
            case .show:
                return .none
            }
        }
    }

    // We want to update the saved shared data for items not having a registration date.
    // Having a registration date, we'll make sure that we satisfy item first presentation delay, if item demands it.
    private func updateWhatsNewData(for items: [WhatsNew.Item]) {
        var newItemsContainer: [WhatsNew.Item.ID: WhatsNew.PresentationDataItem] = whatsNewData?.items ?? [:]

        let unregisteredItems = items.filter { newItemsContainer[$0.id] == nil }

        for item in unregisteredItems {
            newItemsContainer[item.id] = .init(amount: 0, firstRegistrationDate: now)
        }

        $whatsNewData.withLock { $0 = WhatsNew.PresentationData(items: newItemsContainer) }
    }
}

@Reducer
public struct WhatsNewPresenterFeature {
    @ObservableState
    public struct State: Equatable {
        public let item: WhatsNew.Item

        public init(item: WhatsNew.Item) {
            self.item = item
        }
    }

    public enum Action {
        case dismissItem
    }

    @Dependency(\.date.now) private var now
    @Shared(.whatsNew) private var whatsNewData

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .dismissItem:
                updateWhatsNewData(with: state.item)
                return .none
            }
        }
    }

    // Once an item has been shown and is dismissed, we'll update its lastPresentationDate and presentationAmount
    // making sure we copy and update appropriate fields.
    private func updateWhatsNewData(with item: WhatsNew.Item) {
        let newItem: WhatsNew.PresentationDataItem
        var newItemsContainer: [WhatsNew.Item.ID: WhatsNew.PresentationDataItem]

        if let whatsNewData {
            if let previousItem = whatsNewData.items[item.id] {
                newItem = WhatsNew.PresentationDataItem(
                    amount: previousItem.amount + 1,
                    firstRegistrationDate: previousItem.firstRegistrationDate,
                    lastPresentationDate: now
                )
            } else {
                newItem = WhatsNew.PresentationDataItem(amount: 1, firstRegistrationDate: now, lastPresentationDate: now)
            }
            newItemsContainer = whatsNewData.items
            newItemsContainer[item.id] = newItem
        } else {
            newItem = WhatsNew.PresentationDataItem(amount: 1, firstRegistrationDate: now, lastPresentationDate: now)
            newItemsContainer = [item.id: newItem]
        }

        $whatsNewData.withLock { $0 = WhatsNew.PresentationData(items: newItemsContainer) }
    }
}
