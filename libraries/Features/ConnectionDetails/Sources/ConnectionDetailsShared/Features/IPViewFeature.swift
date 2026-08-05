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
import Foundation
import Strings
import VPNAppCore

@Reducer
public struct IPViewFeature {
    @ObservableState
    public struct State: Equatable {
        /// Whether the user's own address is concealed. Starts hidden so it never reaches the screen
        /// — or a screenshot — unasked.
        public var userIPHidden = true

        @SharedReader(.userIP) public var userIP: String?
        @SharedReader(.connectionState) private var connectionState: ConnectionState

        public init() {}

        /// The address the user's traffic leaves the VPN from, or `nil` when none is known.
        public var vpnIp: String? {
            connectionState.vpnExitIP
        }

        /// Whether the reveal toggle has an address to reveal.
        public var canRevealUserIP: Bool {
            userIP != nil
        }

        /// The user's own address as the row should render it: the address itself, a mask of the
        /// matching family while it is concealed, or a placeholder when none is known — never a mask
        /// standing in for a value we don't have.
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
