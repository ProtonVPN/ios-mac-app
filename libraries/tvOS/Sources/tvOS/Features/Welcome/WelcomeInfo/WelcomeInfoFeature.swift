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
import SwiftUI

@Reducer
struct WelcomeInfoFeature {
    @ObservableState
    enum State: Equatable {
        case createAccount
        case freeUpsell

        struct Model {
            let title: LocalizedStringKey
            let subtitle: LocalizedStringKey
            let url: String
            let displayURL: String?
        }

        var model: Model {
            switch self {
            case .createAccount:
                    .init(title: "Create your Proton Account",
                          subtitle: "Scan the QR code or go to\n",
                          url: "https://account.protonvpn.com/pricing",
                          displayURL: "protonvpn.com/tv")
            case .freeUpsell:
                    .init(title: "Using Proton Free?",
                          subtitle: "Proton VPN for Apple TV is available on all paid plans. You can check and manage your subscription on our website.",
                          url: "https://account.protonvpn.com/pricing",
                          displayURL: nil)
            }
        }
    }

    enum Action { }

    var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
