//
//  Created on 08/01/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Strings
import VPNAppCore
import VPNShared

@Reducer
public struct DefaultProfileFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable, Identifiable {
        let serverOffering: ServerOffering
        public let extraMargin: Bool
        let isFastestConnection: Bool
        let defaultAccessTier: Int

        public var id: String { serverOffering.description }

        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.userTier) var userTier: Int?

        // Computed properties
        var profile: Profile {
            @Dependency(\.propertiesManager) var propertiesManager
            switch serverOffering {
            case .random:
                return Profile(
                    id: "st_r",
                    accessTier: defaultAccessTier,
                    profileIcon: .arrowsSwapRight,
                    profileType: .system,
                    serverType: propertiesManager.serverTypeToggle,
                    serverOffering: serverOffering,
                    name: Localizable.random,
                    connectionProtocol: propertiesManager.connectionProtocol
                )
            default:
                return Profile(
                    id: "st_f",
                    accessTier: defaultAccessTier,
                    profileIcon: .bolt,
                    profileType: .system,
                    serverType: propertiesManager.serverTypeToggle,
                    serverOffering: serverOffering,
                    name: Localizable.fastest,
                    connectionProtocol: propertiesManager.connectionProtocol
                )
            }
        }

        var isConnected: Bool {
            guard case .connected = vpnConnectionStatus else {
                return false
            }

            @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
            @Dependency(\.safeModePropertyProvider) var safeModePropertyProvider
            @Dependency(\.natTypePropertyProvider) var natTypePropertyProvider
            @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
            @Dependency(\.propertiesManager) var propertiesManager
            let connectionSpec = ConnectionSpec(
                connectionRequest: profile.connectionRequest(
                    withDefaultNetshield: netShieldPropertyProvider.getNetShieldType(),
                    withDefaultNATType: natTypePropertyProvider.getNATType(),
                    withDefaultSafeMode: safeModePropertyProvider.getSafeMode(),
                    withDefaultPortForwarding: portForwardingPropertyProvider.getPortForwarding(),
                    trigger: .profile
                )
            )

            return propertiesManager.lastConnectionIntent == connectionSpec
        }

        var isConnecting: Bool {
            guard case let .connecting(connectionSpec, _) = vpnConnectionStatus else {
                return false
            }

            @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
            @Dependency(\.safeModePropertyProvider) var safeModePropertyProvider
            @Dependency(\.natTypePropertyProvider) var natTypePropertyProvider
            @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
            let expectedSpec = ConnectionSpec(
                connectionRequest: profile.connectionRequest(
                    withDefaultNetshield: netShieldPropertyProvider.getNetShieldType(),
                    withDefaultNATType: natTypePropertyProvider.getNATType(),
                    withDefaultSafeMode: safeModePropertyProvider.getSafeMode(),
                    withDefaultPortForwarding: portForwardingPropertyProvider.getPortForwarding(),
                    trigger: .profile
                )
            )

            return connectionSpec == expectedSpec
        }

        var isCurrentlyConnected: Bool {
            isConnected || isConnecting
        }

        var isUsersTierTooLow: Bool {
            if isFastestConnection {
                return false // Fastest connection is available for free users
            }
            return userTier ?? 0 < defaultAccessTier
        }

        public var title: String {
            switch serverOffering {
            case .fastest:
                Localizable.fastestConnection
            case .random:
                Localizable.randomConnection
            default:
                ""
            }
        }

        var alphaOfMainElements: Double {
            isUsersTierTooLow ? 0.5 : 1.0
        }

        // MARK: - Init

        public init(
            serverOffering: ServerOffering,
            extraMargin: Bool
        ) {
            self.serverOffering = serverOffering
            self.extraMargin = extraMargin
            self.isFastestConnection = false
            self.defaultAccessTier = .paidTier
        }

        public init(
            serverOffering: ServerOffering,
            extraMargin: Bool,
            isFastestConnection: Bool
        ) {
            self.serverOffering = serverOffering
            self.extraMargin = extraMargin
            self.isFastestConnection = isFastestConnection
            self.defaultAccessTier = .paidTier
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case connectTapped
        case connectionStatusChanged(VPNConnectionStatus)

        case connectToProfile(Profile)
        case disconnectRequested
        case stopConnectingRequested
        case showProfilesUpsell
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .connectTapped:
                handleConnect(state: state)

            case .connectionStatusChanged:
                .none

            case .binding:
                .none

            case .connectToProfile, .disconnectRequested, .stopConnectingRequested, .showProfilesUpsell:
                .none
            }
        }
    }

    // MARK: - Private Methods

    private func handleConnect(state: State) -> Effect<Action> {
        print("Connect requested by selecting default profile")

        // Skip authorization check for fastest connection (free users)
        if !state.isFastestConnection {
            @Dependency(\.profileAuthorizer) var authorizer
            guard authorizer.canUseProfiles else {
                print("Connect to profile rejected because user is on free plan")
                return .send(.showProfilesUpsell)
            }
        }

        if state.isConnecting {
            print("VPN is connecting. Will stop connecting.")
            return .send(.stopConnectingRequested)
        }

        if state.isConnected {
            print("VPN is connected already. Will be disconnected.")
            return .send(.disconnectRequested)
        }

        print("Will connect to \(state.profile.name)")
        return .send(.connectToProfile(state.profile))
    }
}
