//
//  Created on 05/06/2023.
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
import Combine
import Home
import Theme
import SwiftUI
import Strings
import VPNShared

import Dependencies

public struct ConnectionStatusView: View {

    let store: StoreOf<ConnectionStatusFeature>

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

    func locationText(protectionState: ProtectionState) -> Text? {
        switch protectionState {
        case .protected:
            return nil
        case let .unprotected(country, ip),
            let .protecting(country, ip):
            return Text(country)
                .font(.themeFont(.body2()))
                .foregroundColor(Color(.text))
            + Text(" • ")
                .foregroundColor(Color(.text))
            + Text(ip)
                .font(.themeFont(.body2()))
                .foregroundColor(Color(.text, .weak))
        }
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

    func titleView(protectionState: ProtectionState) -> some View {
        HStack(alignment: .bottom) {
            if case .unprotected = protectionState {
                Theme.Asset.icLockOpenFilled2
                    .swiftUIImage
                    .styled(.danger)
            }
            if case .protecting = protectionState {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
            }
            if case .protected = protectionState {
                Theme.Asset.icLockFilled
                    .swiftUIImage
                    .foregroundColor(Color(.background, .success))
                Text(Localizable.connectionStatusProtected) 
                    .font(.themeFont(.body1(.semibold)))
                    .foregroundColor(Color(.background, .success))
            }
        }
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack(alignment: .top) {
                LinearGradient(colors: [gradientColor(protectionState: viewStore.protectionState).opacity(0.5), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    titleView(protectionState: viewStore.protectionState)
                        .frame(height: 58)
                    if let title = title(protectionState: viewStore.protectionState) {
                        Text(title)
                            .font(.themeFont(.body1(.semibold)))
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
                    .background(Color(.background).opacity(0.4))
                    .background(.translucentLight,
                                in: RoundedRectangle(cornerRadius: .themeRadius8,
                                                     style: .continuous))
                    .padding(.horizontal, .themeSpacing16)
                }
            }
            .frame(height: 200)
        }
    }
}

struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                ConnectionStatusView(store: Store(initialState: ConnectionStatusFeature.State(protectionState: .random)) {
                    ConnectionStatusFeature()
                })
                Spacer()
            }
            .previewDisplayName("protected")
            VStack {
                ConnectionStatusView(store: Store(initialState: ConnectionStatusFeature.State(protectionState: .unprotected(country: "Poland", ip: "192.168.1.0"))) {
                    ConnectionStatusFeature()
                })
                Spacer()
            }
            .previewDisplayName("unprotected")
            VStack {
                ConnectionStatusView(store: Store(initialState: ConnectionStatusFeature.State(protectionState: .protecting(country: "Poland", ip: "192.168.1.0"))) {
                    ConnectionStatusFeature()
                })
                Spacer()
            }
            .background(Color.black)
            .previewDisplayName("protecting")
        }
    }
}
