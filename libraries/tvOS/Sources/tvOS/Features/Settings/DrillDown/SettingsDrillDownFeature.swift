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
import SwiftUI

@Reducer
struct SettingsDrillDownFeature {
    @ObservableState
    enum State: Equatable {
        case supportCenter
        case contactUs
        case privacyPolicy

        func model() -> Model {
            switch self {
            case .supportCenter:
                return .supportCenter()
            case .contactUs:
                return .contactUs()
            case .privacyPolicy:
                return .privacyPolicy()
            }
        }
    }

    struct Model {
        let title: LocalizedStringKey
        let description: LocalizedStringKey
        let url: String
        let displayURL: String

        static func contactUs() -> Self {
            return .init(title: "Contact us",
                         description: "If you’re having trouble using Proton VPN, our customer support team is happy to help.\n\nJust scan the QR code or go to",
                         url: "https://protonvpn.com/support-form",
                         displayURL: " protonvpn.com/support-form")
        }

        static func supportCenter() -> Self {
            return .init(title: "Support Center",
                         description: "Need help setting up or using Proton VPN?\n\nVisit our online Support Center for troubleshooting tips, setup guides, and answers to FAQs.\n\nJust scan the QR code or go to",
                         url: "https://protonvpn.com/support/",
                         displayURL: " protonvpn.com/support")
        }

        static func privacyPolicy() -> Self {
            return .init(title: "Privacy policy",
                         description: "To read our privacy policy, scan the QR code or go to",
                         url: "https://protonvpn.com/privacy-policy",
                         displayURL: " protonvpn.com/privacy-policy")
        }
    }

    enum Action {

    }

    var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
