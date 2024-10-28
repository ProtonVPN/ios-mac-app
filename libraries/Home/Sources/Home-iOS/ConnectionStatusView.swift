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
import ProtonCoreUIFoundations
import NetShield_iOS

import Dependencies
import Localization

@available(iOS 17, *)
public struct ConnectionStatusView: View {
    @SwiftUI.Bindable var store: StoreOf<ConnectionStatusFeature>

    private static let headerHeight: CGFloat = 58
    private static let viewHeight: CGFloat = 200
    private static let headerPaddingHeight: CGFloat = 13

    func title(protectionState: ProtectionState) -> String? {
        switch protectionState {
        case .protected, .protectedSecureCore:
            return nil
        case .unprotected:
            return Localizable.connectionStatusUnprotected
        case .protecting:
            return Localizable.connectionStatusProtecting
        }
    }

    func locationText(protectionState: ProtectionState) -> Text? {
        let displayCountry: String?
        let displayIP: String?
        switch protectionState {
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

    func gradientColor(protectionState: ProtectionState) -> Color {
        switch protectionState {
        case .protected, .protectedSecureCore:
            return Color(.background, .success)
        case .unprotected:
            return Color(.background, .danger)
        case .protecting:
            return .white
        }
    }

    private var protectedText: Text {
        Text(Localizable.connectionStatusProtected)
            .font(.themeFont(.body1(.semibold)))
            .foregroundColor(Color(.background, .success))
    }

    func titleView(protectionState: ProtectionState) -> some View {
        HStack(alignment: .bottom) {
            switch protectionState {
            case .protected:
                IconProvider.lockFilled
                    .foregroundColor(Color(.background, .success))
                protectedText
            case .protectedSecureCore:
                IconProvider.locksFilled
                    .foregroundColor(Color(.background, .success))
                protectedText
            case .protecting:
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
            case .unprotected:
                IconProvider.lockOpenFilled2
                    .styled(.danger)
            }
        }
    }
    
    public var body: some View {
        WithPerceptionTracking {
            ZStack(alignment: .top) {
                LinearGradient(colors: [gradientColor(protectionState: store.protectionState).opacity(0.5), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    if !store.stickToTop {
                        titleView(protectionState: store.protectionState)
                            .frame(height: Self.headerHeight)
                        if let title = title(protectionState: store.protectionState) {
                            Text(title)
                                .font(.themeFont(.body1(.semibold)))
                            Spacer()
                                .frame(height: 8)
                        }
                    }
                    ZStack {
                        if let locationText = locationText(protectionState: store.protectionState) {
                            locationText
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        } else if case .protected(let netShield) = store.protectionState {
                            NetShieldStatsView(viewModel: netShield)
                        } else if case .protectedSecureCore(let netShield) = store.protectionState {
                            NetShieldStatsView(viewModel: netShield)
                        }
                    }
                    .background(.translucentLight,
                                in: RoundedRectangle(cornerRadius: .themeRadius8,
                                                     style: .continuous))
                    .padding(.horizontal, .themeSpacing16)
                }
            }
            .frame(height: 200)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: .themeSpacing8) {
                        titleView(protectionState: store.protectionState)

                        if let title = title(protectionState: store.protectionState) {
                            Text(title)
                                .font(.themeFont(.body1(.semibold)))
                        }
                    }
                    .frame(height: Self.headerHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

            }

            .navigationBarTitleDisplayMode(.inline)
            .toolbar(store.stickToTop ? .visible : .hidden, for: .navigationBar)
            .task { await store.send(.watchConnectionStatus).finish() }
        }
    }
}

#Preview("protected") {
    guard #available(iOS 17, *) else { return EmptyView() }
    @Shared(.protectionState) var protectionState: ProtectionState = .protected(netShield: .random)
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

#Preview("unprotected") {
    guard #available(iOS 17, *) else { return EmptyView() }
    @Shared(.protectionState) var protectionState: ProtectionState = .unprotected
    @Shared(.userCountry) var userCountry: String? = "PL"
    @Shared(.userIP) var userIP: String? = "123.456.789.0"
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

#Preview("protecting") {
    guard #available(iOS 17, *) else { return EmptyView() }
    @Shared(.protectionState) var protectionState: ProtectionState = .protecting(country: "PL", ip: "123.456.789.0")
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
    .background(Color.black)
}
