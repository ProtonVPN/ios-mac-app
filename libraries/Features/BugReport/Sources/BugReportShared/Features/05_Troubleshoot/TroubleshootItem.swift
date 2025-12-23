//
//  TroubleshootItem.swift
//  vpncore - Created on 26.02.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import ComposableArchitecture
import Domain
import Foundation
import Sharing
import Strings

@Reducer
public struct TroubleshootItem {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let id: Int
        public let title: String
        public let description: NSAttributedString
        public let type: ItemType

        @Shared(.alternativeRouting) var alternativeRouting

        public enum ItemType: Equatable {
            case basic
            case alternativeRouting
        }

        public init(
            id: Int,
            title: String,
            description: NSAttributedString,
            type: ItemType
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.type = type
        }
    }

    public enum Action: Sendable {
        case toggleAlternativeRouting(isOn: Bool)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .toggleAlternativeRouting(isOn):
                state.$alternativeRouting.withLock { $0 = isOn }
                return .none
            }
        }
    }
}
