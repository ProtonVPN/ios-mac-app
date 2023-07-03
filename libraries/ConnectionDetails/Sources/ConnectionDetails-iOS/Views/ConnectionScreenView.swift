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
import Strings
import ConnectionDetails
import VPNAppCore
import Theme
import SharedViews

public struct ConnectionScreenFeature: ReducerProtocol {

    public struct State: Equatable {
        public var ipViewState: IPViewFeature.State
        public var connectionDetailsState: ConnectionDetailsFeature.State
        public var connectionFeatures: [ConnectionSpec.Feature]
        public var isSecureCore: Bool
        public var connectionSpec: ConnectionSpec
        public var vpnConnectionActual: VPNConnectionActual?

        public init(ipViewState: IPViewFeature.State, connectionDetailsState: ConnectionDetailsFeature.State, connectionFeatures: [ConnectionSpec.Feature], isSecureCore: Bool, connectionSpec: ConnectionSpec, vpnConnectionActual: VPNConnectionActual?) {
            self.ipViewState = ipViewState
            self.connectionDetailsState = connectionDetailsState
            self.connectionFeatures = connectionFeatures
            self.isSecureCore = isSecureCore
            self.connectionSpec = connectionSpec
            self.vpnConnectionActual = vpnConnectionActual
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
    }

    public init() {
    }

    public var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {

            case .watchConnectionStatus:
                return .run { send in
                    @Dependency(\.watchVPNConnectionStatus) var watchVPNConnectionStatus
                    for await vpnStatus in await watchVPNConnectionStatus() {
                        await send(.newConnectionStatus(vpnStatus), animation: .default)
                    }
                }

            case .newConnectionStatus(let connectionStatus):
                switch connectionStatus {
                case .connected(let intent, let actual), .connecting(let intent, let actual), .loadingConnectionInfo(let intent, let actual), .disconnecting(let intent, let actual):
                    state.connectionSpec = intent
                    state.vpnConnectionActual = actual

                case .disconnected:
                    break // todo: close this view?
                }
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
                    ConnectionFlagInfoView(location: viewStore.connectionSpec.location)

                    Spacer()

                    Button(action: {
                        viewStore.send(.close)
                    }, label: {
                        Asset.icCross.swiftUIImage
                            .resizable().frame(width: closeButtonSize, height: closeButtonSize)
                            .foregroundColor(Color(.icon, .weak))
                    })
                    .padding([.leading], .themeRadius16)
                    .padding([.trailing], .themeRadius8)
                }
                .padding(.themeSpacing16)

                .task { await viewStore.send(.watchConnectionStatus).finish() }
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
        .background(Color(.background, .strong))
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
                        connectionDetailsState: ConnectionDetailsFeature.State(
                            connectedSince: Date.init(timeIntervalSinceNow: -12345),
                            country: "Lithuania",
                            city: "Siauliai",
                            server: "LT#5",
                            serverLoad: 23,
                            protocolName: "WireGuard"
                        ),
                        connectionFeatures: [.p2p, .tor, .smart, .streaming],
                        isSecureCore: true,
                        connectionSpec: ConnectionSpec(
                            location: .secureCore(.hop(to: "US", via: "CH")),
                            features: []),
                        vpnConnectionActual: nil
                       ),
                    reducer: ConnectionScreenFeature()
                )
            )
        }
        .background(Color(.background, .strong))
    }
}
