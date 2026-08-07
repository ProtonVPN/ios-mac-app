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

import ComposableArchitecture
import Connection
import ConnectionDetailsShared
import Domain
import Persistence
import SharedViews
import Strings
import SwiftUI
import Theme
import VPNAppCore

public struct ConnectionScreenView: View {
    let store: StoreOf<ConnectionScreenFeature>

    private enum AccessibilityIdentifiers {
        static let connectionScreenInfo: String = "connection_screen_info"
    }

    @ScaledMetric var closeButtonSize: CGFloat = 24
    @Environment(\.dismiss) var dismiss

    public init(store: StoreOf<ConnectionScreenFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                if let spec = store.connectionState.resolvedSpec {
                    ConnectionFlagInfoView(
                        intent: spec,
                        isPinned: false,
                        server: store.connectionState.resolvedServer,
                        isConnected: false,
                        images: .coreImages
                    )
                    .font(.body1(.semibold))
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.connectionScreenInfo
                    )
                }

                Spacer()

                Button(action: {
                    dismiss()
                }, label: {
                    Theme.Asset.Icons.cross.swiftUIImage
                        .resizable()
                        .frame(width: closeButtonSize, height: closeButtonSize)
                        .foregroundColor(Color(.icon, .weak))
                })
                .padding([.leading], .themeRadius16)
                .padding([.trailing], .themeRadius8)
                .accessibilityLabel(Localizable.connectionDetailsAccessibilityClose)
            }
            .padding(.themeSpacing16)

            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    IPView(store: store.scope(state: \.ipViewState, action: \.ipViewAction))

                    ConnectionDetailsView(store: store.scope(
                        state: \.connectionDetailsState,
                        action: \.connectionDetailsAction
                    ))

                    if !store.connectionFeatures.isEmpty || store.isSecureCore {
                        Text(Localizable.connectionDetailsFeaturesTitle)
                            .font(.themeFont(.body2()))
                            .foregroundColor(Color(.text, .weak))
                            .padding(.top, .themeSpacing24)
                            .padding(.bottom, .themeSpacing8)

                        if store.isSecureCore {
                            FeatureInfoView(secureCore: true)
                                .padding(.bottom, .themeRadius8)
                        }

                        ForEach(store.connectionFeatures) { feature in
                            FeatureInfoView(for: feature)
                        }
                        .padding(.bottom, .themeRadius8)
                    }
                }
                .padding(.horizontal, .themeSpacing16)
            }
        }
        .padding(.top, .themeSpacing16)
        .background(Color(.background, .strong))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview {
        let store = {
            let spec = ConnectionSpec(location: .secureCore(.hop(to: "US", via: "CH")), features: [])
            let server = Server.mock(
                serverModelId: "server-id",
                serverExitIP: "102.107.197.6",
                serverName: "SER#123",
                country: "US",
                city: "City",
                coordinates: .mockPoland()
            )
            let connectedState = ConnectionState.connected(
                .init(connectionSpec: spec, tunnelProtocol: .wireGuard, peerIDs: [], killSwitch: false),
                .init(currentPeer: server, connectionDate: .now, protocolConnectionData: .proTUN(.init(
                    transport: .udp,
                    serverExitV4: nil,
                    userISP: nil,
                    userIP: nil
                )))
            )

            @Shared(.connectionState) var connectionState: ConnectionState
            $connectionState.withLock { $0 = connectedState }

            @Shared(.userLocation) var userLocation: StoredUserLocation?
            $userLocation.withLock { $0 = .measured(.init(ip: "127.0.0.1", country: "CH", isp: "Swisscom"), at: .now) }

            return StoreOf<ConnectionScreenFeature>(
                initialState: connectionState.connectionScreenFeatureState()!,
                reducer: { ConnectionScreenFeature() }
            )
        }()
        ConnectionScreenView(store: store)
            .background(Color(.background, .strong))
            .preferredColorScheme(.dark)
    }
#endif
