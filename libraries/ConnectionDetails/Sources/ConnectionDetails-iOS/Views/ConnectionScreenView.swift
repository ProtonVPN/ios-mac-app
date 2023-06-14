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
import VPNShared
import Theme

public struct ConnectionScreenFeature: Reducer {

    public struct State: Equatable {
        public var ipViewState: IPViewFeature.State
        public var connectionDetailsState: ConnectionDetailsFeature.State
        public var connectionFeatures: [ConnectionSpec.Feature]
        public var isSecureCore: Bool

        public init(ipViewState: IPViewFeature.State, connectionDetailsState: ConnectionDetailsFeature.State, connectionFeatures: [ConnectionSpec.Feature], isSecureCore: Bool) {
            self.ipViewState = ipViewState
            self.connectionDetailsState = connectionDetailsState
            self.connectionFeatures = connectionFeatures
            self.isSecureCore = isSecureCore
        }
    }

    public enum Action: Equatable {
        case close
        case ipViewAction(IPViewFeature.Action)
        case connectionDetailsAction(ConnectionDetailsFeature.Action)
    }

    public init() {
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            return .none
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
                HStack {

                    Spacer()

                    Button(action: {
                        viewStore.send(.close)
                    }, label: {
                        Asset.icCross.swiftUIImage
                            .resizable().frame(width: closeButtonSize, height: closeButtonSize)
                            .foregroundColor(Color(.icon, .weak))
                    })
                    .padding(.themeRadius16)
                }
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
    }
}

// MARK: - Previews

struct ConnectionScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConnectionScreenView(store: Store(initialState: ConnectionScreenFeature.State(
                ipViewState: IPViewFeature.State(localIP: "127.0.0.1", vpnIp: "102.107.197.6"),
                connectionDetailsState: ConnectionDetailsFeature.State(connectedSince: Date.init(timeIntervalSinceNow: -12345),
                                                                       country: "Lithuania",
                                                                       city: "Siauliai",
                                                                       server: "LT#5",
                                                                       serverLoad: 23,
                                                                       protocolName: "WireGuard"), connectionFeatures: [.p2p, .tor, .smart, .streaming],
                isSecureCore: true),
                                              reducer: ConnectionScreenFeature()))
        }
        .background(Color(.background, .strong))
    }
}
