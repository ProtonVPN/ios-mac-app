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
import Connection
import ExtensionSync

@Reducer
public struct LocalAgentNoticeFeature {
    @ObservableState
    public struct State: Equatable {
        /// The 2FA requirement that prompted this notice. The sheet is only presented for 2FA notices;
        /// setting-refusal notices are surfaced as a plain alert by the parent instead.
        public let twoFactorError: LocalAgent.Error

        public init(twoFactorError: LocalAgent.Error) {
            assert(twoFactorError.twoFactorRequired, "Non-2FA error presented in LocalAgentNoticeFeature?")
            self.twoFactorError = twoFactorError
        }
    }

    public enum Action {
        case openFidoAuthentication
        case disconnect
    }

    public init() {}

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
