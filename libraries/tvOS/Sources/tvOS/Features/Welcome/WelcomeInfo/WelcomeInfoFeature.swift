//
//  Created on 30/04/2024.
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

import Foundation
import ComposableArchitecture

@Reducer
struct WelcomeInfoFeature {
    @ObservableState
    enum State: Equatable {
        case createAccount
        case freeUpsell

        struct Model {
            let title: String
            let subtitle: String
            let url: String
            let displayURL: String
        }

        var model: Model {
            switch self {
            case .createAccount:
                    .init(title: "Create your Proton Account",
                          subtitle: "Scan the QR code or go to\n",
                          url: "www.protonvpn.com/tv",
                          displayURL: "protonvpn.com/tv")
            case .freeUpsell:
                    .init(title: "Proton VPN for Apple TV is not available on free plans",
                          subtitle: "Check your subscription on\n",
                          url: "https://account.protonvpn.com/subscription",
                          displayURL: "account.protonvpn.com/subscription")
            }
        }
    }

    enum Action { }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}
