//
//  Created on 07/05/2023.
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

import ComposableArchitecture
import HomeShared
import Strings
import SwiftUI
import Theme

struct ConnectionStatusView: View {
    let store: StoreOf<ConnectionStatusFeature>

    func gradientColor(protectionState: ProtectionState) -> Color {
        switch protectionState {
        case .protected, .protectedSecureCore:
            Color(.background, .success)
        case .unprotected:
            Color(.background, .danger)
        case .authenticationRequired:
            Color(.background, .warning)
        case .protecting:
            .white
        }
    }

    func title(protectionState: ProtectionState) -> String? {
        switch protectionState {
        case .protected, .protectedSecureCore:
            nil
        case .unprotected:
            Localizable.connectionStatusUnprotected
        case .protecting:
            Localizable.connectionStatusProtecting
        case .authenticationRequired:
            "Authentication required"
        }
    }

    func titleView(protectionState: ProtectionState) -> some View {
        HStack(alignment: .bottom, spacing: .themeSpacing8) {
            switch protectionState {
            case .protected:
                Theme.Asset.Icons.lockFilled.swiftUIImage
                    .foregroundColor(Color(.background, .success))
                Text(Localizable.connectionStatusProtected)
                    .themeFont(.title2(emphasised: true))
                    .foregroundColor(Color(.text, .success))
            case .protectedSecureCore:
                Theme.Asset.Icons.locksFilled.swiftUIImage
                    .foregroundColor(Color(.background, .success))
                Text(Localizable.connectionStatusProtected)
                    .themeFont(.title2(emphasised: true))
                    .foregroundColor(Color(.text, .success))
            case .protecting:
                ProgressView()
            case .unprotected:
                Theme.Asset.Icons.lockOpenFilled2.swiftUIImage
                    .styled(.danger)
            case .authenticationRequired:
                Theme.Asset.Icons.exclamationTriangleFilled.swiftUIImage
                    .foregroundColor(Color(.icon, .warning))
            }
        }
    }

    func locationText(protectionState: ProtectionState) -> Text? {
        switch protectionState {
        case .protected, .protectedSecureCore, .authenticationRequired:
            nil
        case let .unprotected(country, ip),
             let .protecting(country, ip):
            Text(country)
                .themeFont(.body(emphasised: true))
                .foregroundColor(Color(.text))
                + Text(" • ")
                .foregroundColor(Color(.text))
                + Text(ip)
                .themeFont(.body())
                .foregroundColor(Color(.text, .weak))
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [gradientColor(protectionState: store.protectionState).opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxHeight: 150)
            VStack(spacing: 0) {
                titleView(protectionState: store.protectionState)
                    .padding(.vertical, .themeSpacing16)
                if let title = title(protectionState: store.protectionState) {
                    Text(title)
                        .themeFont(.title3(emphasised: true))
                        .foregroundStyle(Color(.text))
                    Spacer()
                        .frame(height: 8)
                }
                ZStack {
                    if let locationText = locationText(protectionState: store.protectionState) {
                        locationText
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    } else if case .protected = store.protectionState {
                        NetShieldStatsView(viewModel: store.netShield)
                    }
                }
                .background(
                    .thinMaterial,
                    in: RoundedRectangle(
                        cornerRadius: .themeRadius8,
                        style: .continuous
                    )
                )
                .padding(.horizontal, .themeSpacing16)
            }
        }
        .ignoresSafeArea()
        .task { await store.send(.watchConnectionStatus).finish() }
    }
}

struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionStatusView(store: .init(
            initialState: .init(protectionState: .protected),
            reducer: { ConnectionStatusFeature() }
        ))
        .previewDisplayName("Protected")
        ConnectionStatusView(store: .init(
            initialState: .init(protectionState: .protectedSecureCore),
            reducer: { ConnectionStatusFeature() }
        ))
        .previewDisplayName("ProtectedSecureCore")
        ConnectionStatusView(store: .init(
            initialState: .init(protectionState: .unprotected(country: "Poland", ip: "192.168.1.0")),
            reducer: { ConnectionStatusFeature() }
        ))
        .previewDisplayName("Unprotected")
        ConnectionStatusView(store: .init(
            initialState: .init(protectionState: .protecting(country: "Poland", ip: "192.168.1.0")),
            reducer: { ConnectionStatusFeature() }
        ))
        .background(.black)
        .previewDisplayName("Protecting")
    }
}
