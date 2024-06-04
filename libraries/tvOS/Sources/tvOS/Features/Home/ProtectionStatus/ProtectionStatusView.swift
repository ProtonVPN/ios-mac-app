//
//  Created on 04/06/2024.
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

import SwiftUI
import ComposableArchitecture
import ProtonCoreUIFoundations
import Localization
import Domain

struct ProtectionStatusView: View {

    @Bindable var store: StoreOf<ProtectionStatusFeature>

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                protectionTitle
                location
                button
            }
            Spacer()
                .frame(maxWidth: .infinity)
        }
        .onAppear { store.send(.onAppear) }
        .focusSection()
    }

    private var protectionTitle: some View {
        HStack(spacing: .themeSpacing24) {
            protectionIcon
            Text(store.title)
                .font(.title3)
        }
        .foregroundStyle(store.foregroundColor)
    }

    @ViewBuilder
    private var protectionIcon: some View {
        if let icon = store.icon {
            icon.resizable()
                .frame(.square(56))
        } else {
            ProgressView()
        }
    }
    
    @ViewBuilder
    private var locationText: Text? {
        if let location = displayedLocation {
            Text(LocalizationUtility.default.countryName(forCode: location.country) ?? "")
            +
            Text(" • \(location.ip)")
                .foregroundStyle(Color(.text, .weak))
        }
    }

    private var displayedLocation: UserLocation? {
        var country: String?
        var ip: String?
        switch store.connectionState ?? .disconnected {
        case .connected(let connectedCountry, let connectedIP):
            country = connectedCountry
            ip = connectedIP
        default:
            country = store.userLocation?.country
            ip = store.userLocation?.ip
        }
        guard let country, let ip else { return nil }
        return .init(ip: ip, country: country, isp: "")
    }

    private var location: some View {
        locationText
            .font(.body)
            .padding(.vertical, .themeSpacing24)
            .padding(.horizontal, 32)
            .background(.ultraThickMaterial)
            .clipRectangle(cornerRadius: .radius16)
    }

    private var button: some View {
        Button {
            store.send(.userTappedButton)
        } label: {
            Text(store.buttonTitle)
                .font(.body)
                .bold()
                .padding(.vertical, .themeSpacing12)
        }
    }
}
