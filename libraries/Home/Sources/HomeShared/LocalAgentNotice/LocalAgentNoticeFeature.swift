//
//  Created on 15/09/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
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

import CommonNetworking
import ComposableArchitecture
import Darwin

@Reducer
public struct LocalAgentNoticeFeature {
    @ObservableState
    public struct State: Equatable {
        public let localAgentNoticeErrorCode: FourCharCode?

        public init(code: FourCharCode? = nil) {
            self.localAgentNoticeErrorCode = code
        }
    }

    @CasePathable
    public enum Action {
        case openFidoAuthentication
        case disconnect
    }

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .openFidoAuthentication:
                .run { @MainActor _ in
                    @Dependency(\.linkOpener) var linkOpener
                    linkOpener.open(ObfuscatedConstants.fidoPortal)
                }
            case .disconnect:
                .none
            }
        }
    }
}
