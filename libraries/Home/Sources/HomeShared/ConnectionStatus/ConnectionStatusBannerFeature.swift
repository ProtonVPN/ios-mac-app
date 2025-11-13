//
//  Created on 26/11/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Domain
import VPNAppCore

@Reducer
public struct ConnectionStatusBannerFeature {
    public typealias ActionSender = (Action) -> Void

    public enum UpsellMode {
        case netshield
        case serverChange
    }

    @ObservableState
    public struct State: Equatable {
        // This cannot be a regular shared reader, unless we find a way to ensure it is
        // recreated with the correct user defaults key every time the current user changes.
        package var netShieldLevel: NetShieldType? {
            SharedReader(.netShieldLevel).wrappedValue
        }

        @SharedReader(.protectionState) public var protectionState: ProtectionState
        @SharedReader(.userCountry) public var userCountry: String?
        @SharedReader(.userIP) public var userIP: String?
        @SharedReader(.userTier) public var userTier: Int?

        public internal(set) var upsellMode: UpsellMode = .netshield
    }

    @Dependency(\.pushAlert) private var pushAlert
    @Dependency(\.serverChangeAuthorizer) var authorizer

    public enum Action: Equatable {
        case upsellModeRefresh
        case upsellTap
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .upsellModeRefresh:
                // We have currently 2 upsell banners in the connection status section.
                // We show either the netshield upsell or change server banner depending
                // on whether we have the change server counter visible or not.
                switch authorizer.serverChangeAvailability() {
                case .available:
                    state.upsellMode = .netshield
                case let .unavailable(until, _, _):
                    state.upsellMode = .serverChange
                    // Change server block will eventually disappear, so let's wait for the timeout and check again
                    return .run { send in
                        @Dependency(\.continuousClock) var clock
                        try await clock.sleep(for: .seconds(until.timeIntervalSinceNow))
                        await send(.upsellModeRefresh)
                    }
                }
                return .none

            case .upsellTap:
                switch state.upsellMode {
                case .netshield:
                    pushAlert(NetShieldUpsellAlert())
                case .serverChange:
                    pushAlert(AllCountriesUpsellAlert())
                }
                return .none
            }
        }
    }
}
