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

import SwiftUI
import Home
import Theme
import Strings
import ComposableArchitecture

@available(macOS 12.0, *)
struct ConnectionStatusView: View {

    let store: StoreOf<ConnectionStatusFeature>

    public init(store: StoreOf<ConnectionStatusFeature>) {
        self.store = store
    }

    func gradientColor(protectionState: ProtectionState) -> Color {
        switch protectionState {
        case .protected:
            return Color(.background, .success)
        case .unprotected:
            return Color(.background, .danger)
        case .protecting:
            return .white
        }
    }

    func title(protectionState: ProtectionState) -> String? {
        switch protectionState {
        case .protected:
            return nil
        case .unprotected:
            return Localizable.connectionStatusUnprotected
        case .protecting:
            return Localizable.connectionStatusProtecting
        }
    }

    func titleView(protectionState: ProtectionState) -> some View {
        HStack(alignment: .bottom, spacing: .themeSpacing8) {
            if case .unprotected = protectionState {
                Theme.Asset.icLockOpenFilled2
                    .swiftUIImage
                    .styled(.danger)
            }
            if case .protecting = protectionState {
                ProgressView()
            }
            if case .protected = protectionState {
                Theme.Asset.icLockFilled
                    .swiftUIImage
                    .foregroundColor(Color(.background, .success))
                Text(Localizable.connectionStatusProtected)
                    .themeFont(.title2(emphasised: true))
                    .foregroundColor(Color(.text, .success))
            }
        }
    }

    func locationText(protectionState: ProtectionState) -> Text? {
        switch protectionState {
        case .protected:
            return nil
        case let .unprotected(country, ip),
            let .protecting(country, ip):
            return Text(country)
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
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack(alignment: .top) {
                LinearGradient(colors: [gradientColor(protectionState: viewStore.protectionState).opacity(0.5), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                .frame(maxHeight: 150)
                VStack(spacing: 0) {
                    titleView(protectionState: viewStore.protectionState)
                        .padding(.vertical, .themeSpacing16)
                    if let title = title(protectionState: viewStore.protectionState) {
                        Text(title)
                            .themeFont(.title3(emphasised: true))
                            .foregroundStyle(Color(.text))
                        Spacer()
                            .frame(height: 8)
                    }
                    ZStack {
                        if let locationText = locationText(protectionState: viewStore.protectionState) {
                            locationText
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        } else if case .protected(let netShield) = viewStore.protectionState {
                            NetShieldStatsView(viewModel: netShield)
                        }
                    }
                    .background(.translucentLight,
                                in: RoundedRectangle(cornerRadius: .themeRadius8,
                                                     style: .continuous))
                    .padding(.horizontal, .themeSpacing16)
                }
            }
            .ignoresSafeArea()
            .task { await viewStore.send(.watchConnectionStatus).finish() }
        }
    }
}

@available(macOS 12.0, *)
struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {

        ConnectionStatusView(store: .init(initialState: .init(protectionState: .protected(netShield: .random)),
                                          reducer: ConnectionStatusFeature()))
        .previewDisplayName("Protected")
        ConnectionStatusView(store: .init(initialState: .init(protectionState: .unprotected(country: "Poland", ip: "192.168.1.0")),
                                          reducer: ConnectionStatusFeature()))
        .previewDisplayName("Unprotected")
        ConnectionStatusView(store: .init(initialState: .init(protectionState: .protecting(country: "Poland", ip: "192.168.1.0")),
                                          reducer: ConnectionStatusFeature()))
        .background(.black)
        .previewDisplayName("Protecting")
    }
}
