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

import Combine
import ComposableArchitecture
import Dependencies
import HomeShared
import Localization
import NetShield
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme
import VPNAppCore
import VPNShared

@MainActor
public struct ConnectionStatusView: View {
    private static let maxContentWidth: CGFloat = 480

    @Bindable var store: StoreOf<ConnectionStatusFeature>

    /// When the map is in full view the only chrome over it is the tint + lock + title; the NetShield
    /// banner (which belongs with the connection card) is hidden.
    var compact: Bool = false

    private static let headerHeight: CGFloat = 58
    private static let viewHeight: CGFloat = 200
    private static let headerPaddingHeight: CGFloat = 13

    // `.killSwitchActive` never reaches these helpers in practice: `body` renders the
    // KillSwitchBlockingBanner for it instead. It is grouped with `.unprotected` throughout
    // as the accurate fallback.
    private func title(protectionState: ProtectionState) -> String? {
        switch protectionState {
        case .resolving:
            Localizable.connectionStatusLoading
        case .protected, .protectedSecureCore:
            nil
        case .unprotected, .killSwitchActive:
            Localizable.connectionStatusUnprotected
        case .protecting:
            Localizable.connectionStatusProtecting
        }
    }

    private func gradientColor(protectionState: ProtectionState) -> Color {
        switch protectionState {
        case .protected, .protectedSecureCore:
            Color(.background, .success)
        case .unprotected, .killSwitchActive:
            Color(.background, .danger)
        case .protecting, .resolving:
            .white
        }
    }

    private func protectedTitleView(secureCore: Bool) -> some View {
        HStack(spacing: .themeSpacing4) {
            Text((secureCore ? HomeAsset.lockDouble : HomeAsset.lockSingle).swiftUIImage)
                .accessibilityHidden(true)
            Text(Localizable.connectionStatusProtected)
        }
        .font(.themeFont(.body1(.bold)))
        .foregroundColor(Asset.vpnGreen.swiftUIColor)
    }

    @ViewBuilder
    private func titleView(protectionState: ProtectionState) -> some View {
        switch protectionState {
        case .protected:
            protectedTitleView(secureCore: false)
        case .protectedSecureCore:
            protectedTitleView(secureCore: true)
        case .protecting, .resolving:
            ProgressView()
                .controlSize(.regular)
                .tint(.white)
        case .unprotected, .killSwitchActive:
            IconProvider.lockOpenFilled2
                .styled(.danger)
                .accessibilityHidden(true)
        }
    }

    private var protectedText: Text {
        Text(Localizable.connectionStatusProtected)
            .font(.themeFont(.body1(.bold)))
            .foregroundColor(Asset.vpnGreen.swiftUIColor)
    }

    private func toolbarView(protectionState: ProtectionState) -> some View {
        HStack(alignment: .bottom) {
            switch protectionState {
            case .protected:
                IconProvider.lockFilled
                    .foregroundColor(Asset.vpnGreen.swiftUIColor)
                protectedText
            case .protectedSecureCore:
                IconProvider.locksFilled
                    .foregroundColor(Asset.vpnGreen.swiftUIColor)
                protectedText
            case .protecting, .resolving:
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
            case .unprotected, .killSwitchActive:
                IconProvider.lockOpenFilled2
                    .styled(.danger)
            }
        }
    }

    public var body: some View {
        Group {
            if store.protectionState == .killSwitchActive {
                // Advanced kill switch is blocking: show the grey KS overlay in place of the connection status.
                KillSwitchBlockingBanner()
            } else {
                connectionStatus(protectionState: store.protectionState)
            }
        }
        .task { await store.send(.watchConnectionStatus).finish() }
    }

    private func connectionStatus(protectionState: ProtectionState) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [gradientColor(protectionState: protectionState).opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                titleView(protectionState: protectionState)
                    .frame(height: Self.headerHeight)
                if let title = title(protectionState: protectionState) {
                    Text(title)
                        .font(.themeFont(.body1(.bold)))
                    Spacer()
                        .frame(height: .themeSpacing8)
                }
                if !compact {
                    ConnectionStatusBanner(store: store.scope(state: \.connectionStatusBanner, action: \.connectionStatusBanner))
                        .background(
                            .translucentLight,
                            in: RoundedRectangle(
                                cornerRadius: .themeRadius8,
                                style: .continuous
                            )
                        )
                        .frame(maxWidth: Self.maxContentWidth)
                        .padding(.horizontal, .themeSpacing16)
                }
            }
        }
        // Fixed height in both modes so the tint gradient stays localized to the top band and fades out,
        // instead of the greedy gradient filling the whole map (a nil height let it expand).
        .frame(height: Self.viewHeight)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: .themeSpacing8) {
                    toolbarView(protectionState: protectionState)

                    if protectionState != .unprotected, let title = title(protectionState: protectionState) {
                        Text(title)
                            .font(.themeFont(.body1(.semibold)))
                    }
                }
                .frame(height: Self.headerHeight)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("protected", traits: .sizeThatFitsLayout) {
    @SharedReader(.protectionState) var protectionState: ProtectionState = .protected
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

#Preview("unprotected", traits: .sizeThatFitsLayout) {
    @SharedReader(.protectionState) var protectionState: ProtectionState = .unprotected
    @SharedReader(.userCountry) var userCountry: String? = "PL"
    @SharedReader(.userIP) var userIP: String? = "123.456.789.0"
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

#Preview("resolving", traits: .sizeThatFitsLayout) {
    @SharedReader(.protectionState) var protectionState: ProtectionState = .resolving
    @SharedReader(.userCountry) var userCountry: String? = "PL"
    @SharedReader(.userIP) var userIP: String? = "123.456.789.0"
    ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

#Preview("protecting", traits: .sizeThatFitsLayout) {
    @SharedReader(.protectionState) var protectionState: ProtectionState = .protecting(country: "PL", ip: "123.456.789.0")
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
    .background(Color.black)
}
