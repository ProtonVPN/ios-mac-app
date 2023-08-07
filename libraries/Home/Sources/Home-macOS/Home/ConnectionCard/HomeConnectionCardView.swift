//
//  Created on 07/07/2023.
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
import SharedViews

struct HomeConnectionCardView: View {
    @Dependency(\.locale) private var locale

    let model = ConnectionCardModel()

    let item: RecentConnection
    var vpnConnectionStatus: VPNConnectionStatus = .disconnected
    let sendAction: HomeFeature.ActionSender

    var accessibilityText: String {
        let countryName = item.connection.location.text(locale: locale)
        return model.accessibilityText(for: vpnConnectionStatus,
                                       countryName: countryName)
    }

    var header: some View {
        HStack(spacing: .themeSpacing4) {
            Text(model.headerText(for: vpnConnectionStatus))
                .themeFont(.callout())
                .foregroundColor(Color(.text, .weak))
            Spacer()
            Button {
                sendAction(.helpButtonPressed)
            } label: {
                HStack(spacing: .themeSpacing4) {
                    Text(Localizable.actionHelp)
                    Theme.Asset.icQuestionCircle.swiftUIImage
                        .resizable()
                        .frame(.square(16))
                }
            }
            .buttonStyle(HelpButtonStyle())
        }
    }

    var connectionLocation: some View {
        HStack(spacing: .themeSpacing12) {
            VStack(spacing: 0) {
                ConnectionFlagInfoView(intent: item.connection, vpnConnectionActual: nil) // todo: fill in vpnConnectionActual
                Spacer().frame(maxHeight: .infinity)
            }
            Spacer(minLength: 0)
            if showConnectionDetailsEnabled {
                Asset.icChevronRight.swiftUIImage
                    .resizable()
                    .frame(.square(16))
                    .foregroundColor(Color(.icon, .weak))
            }
        }
    }

    var showConnectionDetailsEnabled: Bool {
        switch vpnConnectionStatus {
        case .connected:
            return true
        default:
            return false
        }
    }

    var card: some View {
        HStack(spacing: .themeSpacing8) {
            Button {
                sendAction(.showConnectionDetails)
            } label: {
                connectionLocation
            }
            .help(showConnectionDetailsEnabled ? Localizable.showConnectionDetailsButtonHint : "")
            .buttonStyle(ShowConnectionDetailsButtonStyle(enabled: showConnectionDetailsEnabled))
            .disabled(!showConnectionDetailsEnabled)

            Button(model.buttonText(for: vpnConnectionStatus)) {
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
            }
            .buttonStyle(ConnectButtonStyle(isActive: vpnConnectionStatus == .disconnected))
            .padding(.trailing, .themeSpacing8)
        }
        .padding(.themeSpacing8)
        .background(Color(.background, .weak))
        .themeBorder(color: Color(.border),
                     lineWidth: 1,
                     cornerRadius: .radius12)
    }

    public var body: some View {
        VStack(spacing: .themeSpacing16) {
            header
            card
        }
        .themeFrame(maxWidth: .connectionCardMaxWidth)
        .padding(.themeSpacing16)
        // the accessibility set here currently prevents automation to click on the connect button directly
//        .accessibilityElement()
//        .accessibilityLabel(accessibilityText)
//        .accessibilityAction(named: Text(Localizable.actionConnect)) {
//            sendAction(.connect(item.connection))
//        }
    }
}

// MARK: - Previews

struct ConnectionCard_Previews: PreviewProvider {
    static func card(_ store: ViewStore<HomeFeature.State, HomeFeature.Action>) -> HomeConnectionCardView {
        .init(
            item: store.state.connections.first!,
            vpnConnectionStatus: store.state.vpnConnectionStatus,
            sendAction: { _ = store.send($0) }
        )
    }
    static var previews: some View {
        let storeConnected: StoreOf<HomeFeature> = .init(initialState: .connected, reducer: { HomeFeature() })
        let storeConnecting: StoreOf<HomeFeature> = .init(initialState: .connecting, reducer: { HomeFeature() })
        let storeDisconnected: StoreOf<HomeFeature> = .init(initialState: .disconnected, reducer: { HomeFeature() })
        let storeLoadingConnInfo: StoreOf<HomeFeature> = .init(initialState: .loadingConnectionInfo, reducer: { HomeFeature() })
        let secureCoreFastest: StoreOf<HomeFeature> = .init(initialState: .secureCoreFastest, reducer: { HomeFeature() })
        let secureCoreFastestHop: StoreOf<HomeFeature> = .init(initialState: .secureCoreFastestHop, reducer: { HomeFeature() })
        let secureCoreHopToVia: StoreOf<HomeFeature> = .init(initialState: .secureCoreHopToVia, reducer: { HomeFeature() })
        List {
            WithViewStore(storeConnected, observe: { $0 }, content: card)
            WithViewStore(storeConnecting, observe: { $0 }, content: card)
            WithViewStore(storeDisconnected, observe: { $0 }, content: card)
            WithViewStore(storeLoadingConnInfo, observe: { $0 }, content: card)
            WithViewStore(secureCoreFastest, observe: { $0 }, content: card)
            WithViewStore(secureCoreFastestHop, observe: { $0 }, content: card)
            WithViewStore(secureCoreHopToVia, observe: { $0 }, content: card)
        }
        .previewLayout(.fixed(width: 600, height: 800))
    }
}

private extension HomeFeature.State {
    static var connected: Self {
        .init(connections: [
            .init(
                pinned: false,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .chrząszczyrzewoszczyce
            )
        ],
              connectionStatus: .protected(),
              vpnConnectionStatus: .connected)
    }

    static var connecting: Self {
        .init(connections: [
            .init(
                pinned: false,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .dibba
            )
        ],
              connectionStatus: .protecting(),
              vpnConnectionStatus: .connecting)
    }

    static var disconnected: Self {
        .init(connections: [
            .init(
                pinned: false,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .fastest
            )
        ],
              connectionStatus: .unprotected(),
              vpnConnectionStatus: .disconnected)
    }

    static var loadingConnectionInfo: Self {
        .init(connections: [
            .init(
                pinned: false,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .region
            )
        ],
              connectionStatus: .protecting(),
              vpnConnectionStatus: .loadingConnectionInfo)
    }

    static var secureCoreFastest: Self {
        .init(connections: [
            .init(
                pinned: false,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .secureCoreFastest
            )
        ],
              connectionStatus: .protected(),
              vpnConnectionStatus: .connected)
    }

    static var secureCoreFastestHop: Self {
        .init(connections: [
            .init(
                pinned: false,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .secureCoreFastestHop
            )
        ],
              connectionStatus: .unprotected(),
              vpnConnectionStatus: .disconnected)
    }

    static var secureCoreHopToVia: Self {
        .init(connections: [
            .init(
                pinned: false,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .secureCoreHopToVia
            )
        ],
              connectionStatus: .protected(),
              vpnConnectionStatus: .connected)
    }
}

private extension ConnectionSpec {
    static var chrząszczyrzewoszczyce: Self {
        .init(location: .exact(.paid,
                               number: 42,
                               subregion: "Chrząszczyrzewoszczyce",
                               regionCode: "PL"),
              features: [.p2p])
    }

    static var dibba: Self {
        .init(location: .exact(.paid,
                               number: 42,
                               subregion: "Dibba Al-Fujairah",
                               regionCode: "AE"),
              features: [.smart])
    }

    static var region: Self {
        .init(location: .region(code: "PL"),
              features: [.streaming])
    }

    static var fastest: Self {
        .init(location: .fastest,
              features: [.tor])
    }

    static var secureCoreFastest: Self {
        .init(location: .secureCore(.fastest),
              features: [.partner(name: "DW")])
    }

    static var secureCoreFastestHop: Self {
        .init(location: .secureCore(.fastestHop(to: "PL")),
              features: [])
    }

    static var secureCoreHopToVia: Self {
        .init(location: .secureCore(.hop(to: "AE", via: "PL")),
              features: [])
    }
}

private extension VPNConnectionStatus {
    static var  connected: Self {
        .connected(.dibba, nil)
    }

    static var connecting: Self {
        .connecting(.dibba, nil)
    }

    static var loadingConnectionInfo: Self {
        .loadingConnectionInfo(.chrząszczyrzewoszczyce, nil)
    }

    static var disconnecting: Self {
        .disconnecting(.chrząszczyrzewoszczyce, nil)
    }
}

private extension ConnectionStatusFeature.State {
    static func unprotected() -> Self {
        .init(protectionState: .unprotected(country: "Poland", ip: "192.168.1.0"))
    }
    static func protecting() -> Self {
        .init(protectionState: .protecting(country: "Poland", ip: "192.168.1.0"))
    }
    static func protected() -> Self {
        .init(protectionState: .protected(netShield: .random))
    }
}
