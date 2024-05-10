//
//  Created on 08/05/2024.
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

@Reducer
struct SettingsDrillDownFeature {
    @ObservableState
    struct State: Equatable {
        let title: String
        let description: String
        let url: String

        static func contactUs() -> Self {
            return .init(title: "Title goes here",
                         description: "And here’s a description that gives a little more context to the screen. Since there’s a QR code it probably also includes a",
                         url: "protonvpn.com/url")
        }

        static func reportAnIssue() -> Self {
            return .init(title: "Found a bug? Something missing?",
                         description: "And here’s a description that gives a little more context to the screen. Since there’s a QR code it probably also includes a",
                         url: "protonvpn.com/url")
        }

        static func privacyPolicy() -> Self {
            return .init(title: "Privacy Policy",
                         description: "And here’s a description that gives a little more context to the screen. Since there’s a QR code it probably also includes a",
                         url: "protonvpn.com/url")
        }
    }

    enum Action {

    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}
