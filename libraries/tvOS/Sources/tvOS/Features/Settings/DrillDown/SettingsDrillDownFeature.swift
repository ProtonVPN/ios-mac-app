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
    @CasePathable
    enum State: Equatable {
        case eula
        case dynamic(DynamicDrillDownDestination)
    }

    enum Action {
        case onExitCommand
    }

    @Shared(.mainBackground) var mainBackground: MainBackground = .settingsDrillDown
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onExitCommand:
                mainBackground = .clear
                return .run { _ in await dismiss() }
            }
        }
    }
}

enum DynamicDrillDownDestination: Equatable {
    case supportCenter
    case contactUs
    case privacyPolicy

    var model: DynamicDrillDownModel {
        switch self {
        case .supportCenter:
            return .supportCenter
        case .contactUs:
            return .contactUs
        case .privacyPolicy:
            return .privacyPolicy
        }
    }
}

struct DynamicDrillDownModel {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let url: String?
    let displayURL: String

    static let contactUs = Self(
        title: "Contact us",
        description: "Visit our online Support Center for troubleshooting tips, setup guides, and answers to FAQs.",
        url: nil, // "https://protonvpn.com/support-form?platform=appletv",
        displayURL: ""
    ) //" protonvpn.com/support-form")

    static let supportCenter = Self(
        title: "Support Center",
        description: "Need help setting up or using Proton VPN?\n\nVisit our online Support Center for troubleshooting tips, setup guides, and answers to FAQs.\n\nJust scan the QR code or go to",
        url: "https://protonvpn.com/support/",
        displayURL: " protonvpn.com/support"
    )

    static let privacyPolicy = Self(
        title: "Privacy policy",
        description: "To read our privacy policy, scan the QR code or go to",
        url: "https://proton.me/legal/privacy",
        displayURL: " proton.me/legal/privacy"
    )
}
