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

import Foundation
import ComposableArchitecture

public struct IPViewFeature: ReducerProtocol {

    public struct State: Equatable {
        public var localIP: String?
        public var vpnIp: String
        public var localIpHidden = false

        public init(localIP: String?, vpnIp: String, localIpHidden: Bool = false) {
            self.localIP = localIP
            self.vpnIp = vpnIp
            self.localIpHidden = localIpHidden
        }

        public var buttonIsVisible: Bool { localIP != nil }
    }

    public enum Action: Equatable {
        case changeIPVisibility
    }

    public init() {
    }

    public var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {
            case .changeIPVisibility:
                state.localIpHidden = !state.localIpHidden
                return .none
            }
        }
    }
}
