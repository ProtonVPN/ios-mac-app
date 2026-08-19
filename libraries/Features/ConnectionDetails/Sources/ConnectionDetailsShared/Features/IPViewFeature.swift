//
//  Created on 2023-06-01.
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
import Domain
import Foundation
import Strings

@Reducer
public struct IPViewFeature {
    @ObservableState
    public struct State: Equatable {
        /// Whether the user's own address is concealed. Starts hidden
        public var userIPHidden = true

        @SharedReader(.userLocation) private var userLocation: StoredUserLocation?
        @SharedReader(.connectionState) private var connectionState: ConnectionState

        /// The user's own address, i.e. the one the outside world sees without the VPN.
        public var userIP: String? {
            userLocation?.location.ip
        }

        public init() {}

        /// The address the user's traffic leaves the VPN from, or `nil` when none is known.
        public var vpnIp: String? {
            connectionState.vpnExitIP
        }

        /// Whether the reveal toggle has an address to reveal.
        public var canRevealUserIP: Bool {
            userIP != nil
        }

        /// Whis IP address should be used: the address itself, a mask of the matching family, or a placeholder
        public var displayedUserIP: String {
            guard let userIP else { return Localizable.connectionDetailsIpviewIpUnavailable }
            return userIPHidden ? Self.mask(for: userIP) : userIP
        }

        /// Whether ``displayedUserIP`` is currently concealing a known address.
        public var isUserIPMasked: Bool {
            userIPHidden && userIP != nil
        }

        /// Fixed-width groups, so the mask matches the address family — the tunnel reports either
        /// family — without giving away how long the address is.
        private static func mask(for ip: String) -> String {
            ip.contains(":") ? "****:****:****:****" : "***.***.***.***"
        }
    }

    public enum Action: Equatable {
        case changeIPVisibility
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .changeIPVisibility:
                state.userIPHidden.toggle()
                return .none
            }
        }
    }
}
