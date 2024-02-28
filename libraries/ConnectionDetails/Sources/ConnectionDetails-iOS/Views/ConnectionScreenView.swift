//
//  Created on 2023-06-09.
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

import SwiftUI

import ComposableArchitecture

import ProtonCoreUIFoundations

import Domain
import Localization
import Strings
import Theme
import ConnectionDetails
import Persistence
import SharedViews
import VPNAppCore
import VPNShared

public struct ConnectionScreenFeature: Reducer {

    public struct State: Equatable {
        public var ipViewState: IPViewFeature.State
        public var connectionSpec: ConnectionSpec
        public var vpnConnectionActual: VPNConnectionActual?
        public var vpnServer: VPNServer?

        public init(ipViewState: IPViewFeature.State, connectionSpec: ConnectionSpec, vpnConnectionActual: VPNConnectionActual?) {
            self.ipViewState = ipViewState
            self.connectionSpec = connectionSpec
            self.vpnConnectionActual = vpnConnectionActual
        }

        var connectionDetailsState: ConnectionDetailsFeature.State {
            // Info about current server from ServerStorage
            if let vpnServer {
                return ConnectionDetailsFeature.State(
                    connectedSince: Date(timeIntervalSinceNow: -180), // todo:
                    country: "\(LocalizationUtility().countryName(forCode: vpnServer.logical.exitCountryCode) ?? vpnServer.logical.exitCountryCode)",
                    city: "\(vpnServer.logical.translatedCity ?? "-")",
                    server: vpnServer.logical.name,
                    serverLoad: vpnServer.logical.load,
                    protocolName: "\(vpnConnectionActual?.vpnProtocol.description ?? "")"
                )
            }

            guard let vpnConnectionActual else {
                return ConnectionDetailsFeature.State(
                    connectedSince: Date(),
                    country: "-",
                    city: "-",
                    server: "-",
                    serverLoad: 0,
                    protocolName: "-"
                )
            }

            // Info about current connection in case server info was not received from ServerStorage yet
            return ConnectionDetailsFeature.State(
                connectedSince: Date(timeIntervalSinceNow: -180), // todo:
                country: LocalizationUtility.default.countryName(forCode: vpnConnectionActual.country) ?? vpnConnectionActual.country,
                city: vpnConnectionActual.city ?? "",
                server: vpnConnectionActual.serverName,
                serverLoad: 0,
                protocolName: vpnConnectionActual.vpnProtocol.description
            )
        }

        var isSecureCore: Bool {
            guard let vpnConnectionActual else {
                return false
            }
            return vpnConnectionActual.feature.contains(.secureCore)
        }

        var connectionFeatures: [ConnectionSpec.Feature] {
            guard let vpnConnectionActual else {
                return []
            }
            var features = [ConnectionSpec.Feature]()

            let table: [(ServerFeature, ConnectionSpec.Feature)] = [
                (ServerFeature.tor, ConnectionSpec.Feature.tor),
                (ServerFeature.p2p, ConnectionSpec.Feature.p2p),
                (ServerFeature.streaming, ConnectionSpec.Feature.streaming),
            ]
            for feature in table {
                if vpnConnectionActual.feature.contains(feature.0) {
                    features.append(feature.1)
                }
            }

            if vpnServer?.logical.isVirtual == true {
                features.append(.smart)
            }

            return features
        }

    }

    public enum Action: Equatable {
        case close
        case ipViewAction(IPViewFeature.Action)
        case connectionDetailsAction(ConnectionDetailsFeature.Action)

        /// Watch for changes of VPN connection
        case watchConnectionStatus
        /// Process new VPN connection state
        case newConnectionStatus(VPNConnectionStatus)
        /// Watch changes in the connected server
        case watchServerChanges(String?)
        /// Fill in new server info
        case newServer(VPNServer)
    }

    public init() {
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .watchConnectionStatus:
                return .run { send in
                    @Dependency(\.vpnConnectionStatusPublisher) var vpnConnectionStatusPublisher

                    for await vpnStatus in vpnConnectionStatusPublisher().values {
                        await send(.newConnectionStatus(vpnStatus), animation: .default)
                    }
                }

            case .newConnectionStatus(let connectionStatus):
                switch connectionStatus {
                case .connected(let intent, let actual), .connecting(let intent, let actual), .loadingConnectionInfo(let intent, let actual), .disconnecting(let intent, let actual):
                    state.connectionSpec = intent
                    state.vpnConnectionActual = actual

                    if let actual {
                        return .send(.watchServerChanges(actual.serverModelId))
                    }

                case .disconnected:
                    break // todo: close this view?
                }
                return .none

            case .watchServerChanges(let serverId):
                guard let serverId else {
                    return .none // todo: cancel previous task
                }
                return .run { send in
                    @Dependency(\.serverRepository) var repository
                    let vpnServer = try? repository.getFirstServer(
                        filteredBy: [.logicalID(serverId)],
                        orderedBy: .fastest
                    )
                    await send(.newServer(vpnServer!), animation: .default)
                }

            case .newServer(let vpnServer):
                state.vpnServer = vpnServer
                return .none

            default:
                return .none
            }
        }
    }
}

public struct ConnectionScreenView: View {

    let store: StoreOf<ConnectionScreenFeature>

    @ScaledMetric var closeButtonSize: CGFloat = 24

    public init(store: StoreOf<ConnectionScreenFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading) {
            WithViewStore(self.store, observe: { $0 }, content: { viewStore in
                HStack(alignment: .top) {
                    ConnectionFlagInfoView(intent: viewStore.connectionSpec, vpnConnectionActual: viewStore.vpnConnectionActual, withDivider: false)

                    Spacer()

                    Button(action: {
                        viewStore.send(.close)
                    }, label: {
                        IconProvider.cross
                            .resizable().frame(width: closeButtonSize, height: closeButtonSize)
                            .foregroundColor(Color(.icon, .weak))
                    })
                    .padding([.leading], .themeRadius16)
                    .padding([.trailing], .themeRadius8)
                }
                .padding(.themeSpacing16)

                .task { await viewStore.send(.watchConnectionStatus).finish() }
                .task { await viewStore.send(.watchServerChanges(viewStore.vpnConnectionActual?.serverModelId)).finish() }
            })

            ScrollView(.vertical) {
                WithViewStore(self.store, observe: { $0 }, content: { viewStore in
                    VStack(alignment: .leading) {
                        IPView(store: self.store.scope(
                            state: \.ipViewState,
                            action: ConnectionScreenFeature.Action.ipViewAction)
                        )

                        ConnectionDetailsView(store: self.store.scope(
                            state: \.connectionDetailsState,
                            action: ConnectionScreenFeature.Action.connectionDetailsAction)
                        )

                        if !viewStore.connectionFeatures.isEmpty || viewStore.isSecureCore {

                            Text(Localizable.connectionDetailsFeaturesTitle)
                                .font(.themeFont(.body2()))
                                .foregroundColor(Color(.text, .weak))
                                .padding(.top, .themeSpacing24)
                                .padding(.bottom, .themeSpacing8)

                            if viewStore.isSecureCore {
                                Button(action: {
                                    // todo: action
                                }, label: {
                                    FeatureInfoView(secureCore: true)
                                })
                                .padding(.bottom, .themeRadius8)
                            }

                            ForEach(viewStore.connectionFeatures, content: { feature in
                                Button(action: {
                                    // todo: action
                                }, label: {
                                    FeatureInfoView(for: feature)
                                })
                            })
                            .padding(.bottom, .themeRadius8)

                        }

                    }
                    .padding([.leading, .trailing], .themeSpacing16)
                })
            }
        }
        .padding(.top, .themeSpacing16)
        .background(Color(.background, .strong))
    }
}

extension VpnProtocol {
    public var description: String {
        switch self {
        case .ike:
            return "IKEv2"
        case .openVpn(let transport):
            return "OpenVPN (\(transport.rawValue.uppercased()))"
        case .wireGuard(let transport):
            return "WireGuard (\(transport.rawValue.uppercased()))"
        }
    }
}

// MARK: - Previews

struct ConnectionScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConnectionScreenView(
                store: Store(
                    initialState: ConnectionScreenFeature.State(
                        ipViewState: IPViewFeature.State(
                            localIP: "127.0.0.1",
                            vpnIp: "102.107.197.6"
                        ),
                        connectionSpec: ConnectionSpec(
                            location: .secureCore(.hop(to: "US", via: "CH")),
                            features: []),
                        vpnConnectionActual: VPNConnectionActual(
                            serverModelId: "server-id",
                            serverIPId: "server-ip-id",
                            vpnProtocol: .wireGuard(.udp),
                            natType: .moderateNAT,
                            safeMode: false,
                            feature: .p2p,
                            serverName: "SER#123",
                            country: "US",
                            city: "City"
                        )
                    ),
                    reducer: { ConnectionScreenFeature() }
                )
            )
        }
        .background(Color(.background, .strong))
    }
}
