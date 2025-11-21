//
//  Created on 26/11/2024.
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
import HomeShared
import Localization
import NetShield
import SwiftUI

struct ConnectionStatusBanner: View {
    private enum AccessibilityIdentifiers {
        static let locationText: String = "location_text"
    }

    let store: StoreOf<ConnectionStatusBannerFeature>

    var body: some View {
        switch store.protectionState {
        case let .protected(netShield), let .protectedSecureCore(netShield):
            if (store.userTier ?? .freeTier).isFreeTier {
                ConnectionStatusUpsell(mode: store.upsellMode, sendAction: { _ = store.send($0) })
            } else if store.netShieldLevel == .level2 {
                NetShieldStatsView(viewModel: netShield)
            }
        case .unprotected, .protecting, .resolving:
            locationText()
                .padding(.horizontal, .themeSpacing8)
                .padding(.vertical, .themeSpacing4)
                .accessibilityIdentifier(AccessibilityIdentifiers.locationText)
        }
    }

    private func locationText() -> Text? {
        let displayCountry: String?
        let displayIP: String?
        switch store.protectionState {
        case .resolving:
            return nil
        case .protected, .protectedSecureCore:
            return nil
        case .unprotected:
            let code = store.userCountry
            displayCountry = LocalizationUtility.default.countryName(forCode: code ?? "")
            displayIP = store.userIP
        case let .protecting(country, ip):
            displayCountry = country
            displayIP = ip
        }
        guard let displayIP, let displayCountry else { return nil }
        return Text(displayCountry)
            .font(.themeFont(.body2()))
            .foregroundColor(Color(.text))
            + Text(" • ")
            .foregroundColor(Color(.text))
            + Text(displayIP)
            .font(.themeFont(.body2()))
            .foregroundColor(Color(.text, .weak))
    }
}
