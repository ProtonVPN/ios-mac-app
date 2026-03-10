//
//  Created on 2025-12-23 by Pawel Jurczyk.
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
import ConnectionInventory
import Dependencies
import Domain
import LegacyCommon
import SharedViews
import Sharing
import Strings
import SwiftUI
import Theme
import VPNAppCore

public struct CityStateListView: View {
    @Bindable var store: StoreOf<CityStateListFeature>

    public init(store: StoreOf<CityStateListFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Button {
                    store.send(.expand)
                } label: {
                    HStack {
                        Spacer()
                        Theme.Asset.Icons.chevronDownFilled.swiftUIImage
                            .resizable()
                            .rotationEffect(store.isExpanded ? .degrees(-180) : .degrees(0))
                            .foregroundColor(store.isExpanded ? Color(.icon) : Color(.icon, .weak))
                            .frame(.square(.themeSpacing20))
                    }
                    .padding(.themeSpacing12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.ghost)

                ConnectOnClickButton(
                    action: { store.send(.connectToCountry) },
                    groupInfo: store.groupInfo
                )
            }

            if store.isExpanded {
                switch store.listType {
                case let .cities(groups), let .states(groups):
                    list(groups)
                case let .gateways(servers), let .secureCores(servers):
                    ForEach(servers, id: \.logical.id) { server in
                        ConnectServerOnClickButton(
                            action: { store.send(.connectToServer(server)) },
                            serverInfo: server
                        )
                    }
                }
            }
        }
        .background(store.isExpanded ? Color(.background, .transparent) : .clear)
        .clipRectangle(cornerRadius: .radius8)
        .padding(.trailing, .themeSpacing6)
        .popover(item: $store.scope(state: \.serversList, action: \.serversList), attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) { store in
            ServersListView(store: store)
        }
    }

    private func list(_ groups: [ServerGroupInfo]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(groups, id: \.serverOfferingID) { groupInfo in
                ZStack {
                    expandButton(groupInfo)
                    ConnectOnClickButton(action: { store.send(.connectTo(groupInfo)) }, groupInfo: groupInfo)
                }
            }
        }
    }

    private func expandButton(_ groupInfo: ServerGroupInfo) -> some View {
        Button {
            store.send(.navigateToServers(groupInfo))
        } label: {
            HStack {
                Spacer()
                Theme.Asset.Icons.threeDotsVertical.swiftUIImage
                    .resizable()
                    .foregroundColor(Color(.icon, .weak))
                    .frame(.square(.themeSpacing20))
            }
            .padding(.themeSpacing12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ghost)
    }
}
