//
//  Created on 25.05.23.
//
//  Copyright (c) 2023 Proton AG
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

import ComposableArchitecture
import Dependencies

import Home
import Theme
import Strings
import VPNAppCore

struct HomeConnectionCardView: View {
    @Dependency(\.locale) private var locale

    let model = ConnectionCardModel()

    let item: RecentConnection
    var vpnConnectionStatus: VPNConnectionStatus
    let sendAction: HomeFeature.ActionSender

    var accessibilityText: String {
        let countryName = item.connection.location.text(locale: locale)
        return model.accessibilityText(for: vpnConnectionStatus, countryName: countryName)
    }

    var header: some View {
        HStack {
            Text(model.headerText(for: vpnConnectionStatus))
                .themeFont(.body1())
                .styled()
                .textCase(nil)
            Spacer()
            Text(Localizable.actionHelp)
                .themeFont(.body1())
                .styled(.weak)
                .textCase(nil)
            Theme.Asset.icQuestionCircle.swiftUIImage
                .styled(.weak)
                .frame(.square(16))
        }
        .padding()
    }

    var card: some View {
        VStack {
            HStack {
                let location = item.connection.location
                AnyView(location.flag.appearance(.iOS))
                VStack {
                    Text(location.text(locale: locale))
                        .themeFont(.body1())
                        .styled()
                    if let subtext = location.subtext(locale: locale) {
                        Text(subtext)
                            .themeFont(.caption())
                            .styled(.weak)
                    }
                }
                Spacer()
                Button(action: {
                    sendAction(.showConnectionDetails)
                }, label: {
                    Asset.icChevronUp.swiftUIImage
                })
                .foregroundColor(Color(.icon, .weak))
            }
            .padding()

            Button {
                withAnimation(.easeInOut) {
                    switch vpnConnectionStatus {
                    case .disconnected:
                        sendAction(.connect(item.connection))
                    case .connected:
                        sendAction(.disconnect)
                    case .connecting:
                        sendAction(.disconnect)
                    case .loadingConnectionInfo:
                        sendAction(.disconnect)
                    case .disconnecting:
                        break
                    }
                }
            } label: {
                Text(model.buttonText(for: vpnConnectionStatus))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundColor(Color(.text, .primary))
                    .background(Color(.background, .interactive))
                    .cornerRadius(.themeRadius8)
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color(.background, .weak))
        .border(Color(.border, .strong))
        .cornerRadius(.themeRadius16)
        .padding()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                Rectangle()
                    .fill(Color(.background))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                card
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: Text(Localizable.actionConnect)) {
            sendAction(.connect(item.connection))
        }
    }
}

struct ConnectionCard_Previews: PreviewProvider {
    static var previews: some View {
        let store: StoreOf<HomeFeature> = .init(initialState:
            .init(connections: [
                .init(
                    pinned: false,
                    underMaintenance: false,
                    connectionDate: .now,
                    connection: .init(location: .fastest, features: [])
                )
            ],
                  connectionStatus: .init(protectionState: .protected(netShield: .random)),
                  vpnConnectionStatus: .disconnected),
            reducer: HomeFeature()
        )
        WithViewStore(store, observe: { $0 }) { store in
            List {
                HomeConnectionCardView(
                    item: store.state.connections.first!,
                    vpnConnectionStatus: store.state.vpnConnectionStatus,
                    sendAction: { _ = store.send($0) }
                )
            }
        }
    }
}
