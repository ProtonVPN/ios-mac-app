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
    @Bindable var store: StoreOf<ServersListFeature>

    @Environment(\.dismiss) private var dismiss
    @State var showingFeaturesInfo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            loadingList
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
                .task { store.send(.didAppear) }
        case let .loaded(servers):
            list(servers)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .themeSpacing16) {
            HStack(alignment: .top, spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    IconProvider.chevronLeft.swiftUIImage
                        .resizable()
                        .frame(.square(.themeSpacing20))
                        .padding(.horizontal, .themeSpacing6)
                        .padding(.bottom, .themeSpacing12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                ServerToolbarItemView(city: store.listType.name, countryCode: store.countryCode)
                    .font(AppTheme.Typography.title2(emphasised: false))
            }
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
    }

    private func list(_ servers: [ServerInfo]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(servers, id: \.logical.id) { server in
                    Button {
                        store.send(.connect(serverInfo: server))
                    } label: {
                        ConnectServerOnClickButton(action: { store.send(.connect(serverInfo: server)) }, serverInfo: server)
                    }
                    .buttonStyle(.ghost)
                    .padding(.trailing, .themeSpacing6)
                }
            }
        }
    }
}

struct ConnectServerOnClickButton: View {
    let action: () -> Void
    @State var isHovering: Bool = false

    @SharedReader(.userTier) var userTier

    let serverInfo: ServerInfo

    var body: some View {
        Button(action: action, label: label)
            .onHover { isHovering = $0 }
            .buttonStyle(.ghost)
    }

    private func label() -> some View {
        ZStack {
            HStack(spacing: 0) {
                Text(serverInfo.logical.name)
                    .themeFont(.title2(emphasised: false))
                    .lineLimit(1)
                    .foregroundStyle(Color(.text, isDisabled ? .disabled : .normal))
                Spacer()
                CityStateServerFeaturesView(server: serverInfo)
                    .foregroundStyle(Color(.icon, serverInfo.logical.isUnderMaintenance ? .disabled : .weak))
                Spacer()
                    .frame(width: 90)
            }
            HStack {
                Spacer()
                dynamicView
            }
        }
        .padding(.themeSpacing12)
        .contentShape(Rectangle())
        .help(help)
    }

    @ViewBuilder
    var dynamicView: some View {
        let inMaintenance = serverInfo.logical.isUnderMaintenance
        let load = serverInfo.logical.load

        if inMaintenance {
            IconProvider.wrench.swiftUIImage.resizable()
                .frame(.square(.themeSpacing20))
                .foregroundColor(Color(.icon, .normal))
                .opacity(isHovering ? 1 : 0)
        } else {
            LoadView(load: load)
                .font(.title3(emphasised: false))
        }
    }

    var isDisabled: Bool {
        serverInfo.logical.isUnderMaintenance || userTier?.isFreeTier == true
    }

    var help: String {
        guard userTier?.isFreeTier != true else {
            return Localizable.upgradeToPlus
        }

        guard serverInfo.logical.isUnderMaintenance else {
            return ""
        }
        return Localizable.serverUnderMaintenance
    }
}
