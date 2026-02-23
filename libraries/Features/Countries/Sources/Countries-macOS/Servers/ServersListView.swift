//
//  Created on 2025-12-24 by Pawel Jurczyk.
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

import SwiftUI

import ComposableArchitecture
import Dependencies
import Sharing

import Domain
import Persistence
import ProtonCoreUIFoundations
import SharedViews
import Strings
import Theme
import VPNAppCore

struct ServersListView: View {

    enum Dimensions: CGFloat {
        case popupSize = 350
        case popupBackgroundWorkaroundPadding = -15 // This is added so that the arrow of the popup also has the proper background
    }

    @Bindable var store: StoreOf<ServersListFeature>

    @State var showingFeaturesInfo: Bool = false

    var body: some View {
        loadingList
            .padding(.themeSpacing8)
            .background(
                Color(.background, .weak)
                    .padding(Dimensions.popupBackgroundWorkaroundPadding.rawValue)
            )
            .frame(.square(Dimensions.popupSize.rawValue))
            .task {
                store.send(.didAppear)
            }
    }

    @ViewBuilder
    private var loadingList: some View {
        switch store.list {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .loaded(servers):
            list(servers)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .themeSpacing16) {
            ServerToolbarItemView(kind: store.kind)
                .font(AppTheme.Typography.title2(emphasised: false))
                .padding(.leading, .themeSpacing12)
            HStack(spacing: 0) {
                Text(Localizable.searchServers)
                Spacer(minLength: 0)
                Text(Localizable.connectionDetailsServerLoad)
            }
            .padding(.leading, .themeSpacing8)
            .padding(.trailing, .themeSpacing16)
            .font(.themeFont(.body(emphasised: false)))
            .foregroundColor(Color(.text, .weak))
        }
        .padding(.top, .themeSpacing12)
        .padding(.bottom, .themeSpacing4)
        .background(Color(.background, .weak))
    }

    private func list(_ servers: [ServerInfo]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                Section {
                    ForEach(servers, id: \.logical.id) { server in
                        ConnectServerOnClickButton(action: {
                            store.send(.connect(serverInfo: server))
                        },
                                                   serverInfo: server)
                        .padding(.trailing, .themeSpacing6)
                    }
                } header: {
                    header
                }
            }
        }
    }
}
