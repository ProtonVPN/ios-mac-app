//
//  Created on 2026-02-24 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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

import Domain
import SharedViews
import Sharing
import Strings
import SwiftUI
import Theme

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
                if case .gateway = serverInfo.logical.kind {
                    CountryToolbarItemView(server: serverInfo)
                        .font(.title3(emphasised: false))
                    Spacer()
                } else if serverInfo.logical.feature.contains(.secureCore) {
                    CountryToolbarItemView(server: serverInfo)
                        .font(.title3(emphasised: false))
                    Spacer()
                } else {
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
            }
            HStack {
                Spacer()
                dynamicView
            }
        }
        .padding([.vertical, .leading], .themeSpacing12)
        .contentShape(Rectangle())
        .help(help)
    }

    @ViewBuilder
    var dynamicView: some View {
        let inMaintenance = serverInfo.logical.isUnderMaintenance
        let load = serverInfo.logical.load

        if inMaintenance {
            Theme.Asset.Icons.wrench.swiftUIImage.resizable()
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
