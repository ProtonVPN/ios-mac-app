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
import Strings
import ConnectionDetails
import Persistence
import SharedViews
import VPNAppCore

public struct ConnectionScreenView: View {

    let store: StoreOf<ConnectionScreenFeature>

    @ScaledMetric var closeButtonSize: CGFloat = 24
    @Environment(\.dismiss) var dismiss

    public init(store: StoreOf<ConnectionScreenFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                if let spec = store.vpnConnectionStatus.spec {
                    ConnectionFlagInfoView(intent: spec,
                                           isPinned: false,
                                           vpnConnectionActual: store.vpnConnectionStatus.actual,
                                           withDivider: false,
                                           images: .coreImages)
                }
                Spacer()

                Button(action: {
                    dismiss()
                }, label: {
                    IconProvider
                        .cross
                        .resizable()
                        .frame(width: closeButtonSize, height: closeButtonSize)
                        .foregroundColor(Color(.icon, .weak))
                })
                .padding([.leading], .themeRadius16)
                .padding([.trailing], .themeRadius8)
            }
            .padding(.themeSpacing16)

            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    WithPerceptionTracking {
                        IPView(store: store.scope(state: \.ipViewState,
                                                  action: \.ipViewAction))
                        ConnectionDetailsView(store: store.scope(state: \.connectionDetailsState,
                                                                 action: \.connectionDetailsAction))
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

                            ForEach(store.connectionFeatures, content: { feature in
                                FeatureInfoView(for: feature)

                            })
                            .padding(.bottom, .themeRadius8)
                        }
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

#Preview {
    let spec = ConnectionSpec(location: .secureCore(.hop(to: "US", via: "CH")), features: [])
    let actual = VPNConnectionActual(connectedDate: .now,
                                     serverModelId: "server-id",
                                     serverExitIP: "102.107.197.6",
                                     vpnProtocol: .wireGuard(.udp),
                                     natType: .moderateNAT,
                                     safeMode: false,
                                     feature: .p2p,
                                     serverName: "SER#123",
                                     country: "US",
                                     city: "City",
                                     coordinates: .mockPoland())
    @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
    vpnConnectionStatus = .connected(spec, actual)

    @Shared(.userIP) var userIP: String?
    userIP = "127.0.0.1"
    let store: StoreOf<ConnectionScreenFeature> = .init(initialState: vpnConnectionStatus.actual!.connectionScreenFeatureState()!,
                                                        reducer: { ConnectionScreenFeature() })
    return ConnectionScreenView(store: store)
        .background(Color(.background, .strong))
        .preferredColorScheme(.dark)
}
