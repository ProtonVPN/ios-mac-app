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
import VPNAppCore

import Dependencies
import Localization

@available(iOS 17, *)
@MainActor
public struct ConnectionStatusView: View {

    private static let maxContentWidth: CGFloat = 480

    @SwiftUI.Bindable var store: StoreOf<ConnectionStatusFeature>

    private static let headerHeight: CGFloat = 58
    private static let viewHeight: CGFloat = 200
    private static let headerPaddingHeight: CGFloat = 13

    private func title(protectionState: ProtectionState) -> String? {
        switch protectionState {
        case .resolving:
            return Localizable.connectionStatusLoading
        case .protected, .protectedSecureCore:
            return nil
        case .unprotected:
            return Localizable.connectionStatusUnprotected
        case .protecting:
            return Localizable.connectionStatusProtecting
        }
    }

    private func gradientColor(protectionState: ProtectionState) -> Color {
        switch protectionState {
        case .protected, .protectedSecureCore:
            return Color(.background, .success)
        case .unprotected:
            return Color(.background, .danger)
        case .protecting, .resolving:
            return .white
        }
    }

    @ViewBuilder
    private func protectedTitleView(secureCore: Bool) -> some View {
        HStack(spacing: .themeSpacing4) {
            Text((secureCore ? HomeAsset.lockDouble : HomeAsset.lockSingle).swiftUIImage)
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
        case .unprotected:
            IconProvider.lockOpenFilled2
                .styled(.danger)
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
            case .unprotected:
                IconProvider.lockOpenFilled2
                    .styled(.danger)
            }
        }
    }

    public var body: some View {
        WithPerceptionTracking {
            let protectionState = store.protectionState

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [gradientColor(protectionState: protectionState).opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    if !store.stickToTop {
                        titleView(protectionState: protectionState)
                            .frame(height: Self.headerHeight)
                        if let title = title(protectionState: protectionState) {
                            Text(title)
                                .font(.themeFont(.body1(.bold)))
                            Spacer()
                                .frame(height: .themeSpacing8)
                        }
                    }
                    ConnectionStatusBanner(store: store.scope(state: \.connectionStatusBanner, action: \.connectionStatusBanner))
                        .background(.translucentLight,
                                    in: RoundedRectangle(cornerRadius: .themeRadius8,
                                                         style: .continuous))
                        .frame(maxWidth: Self.maxContentWidth)
                        .padding(.horizontal, .themeSpacing16)
                }
            }
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
            .toolbar(store.stickToTop ? .visible : .hidden, for: .navigationBar)
            .task { await store.send(.watchConnectionStatus).finish() }
        }
    }
}

@available(iOS 17, *)
#Preview("protected", traits: .sizeThatFitsLayout) {
    @Shared(.protectionState) var protectionState: ProtectionState = .protected(netShield: .random)
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

@available(iOS 17, *)
#Preview("unprotected", traits: .sizeThatFitsLayout) {
    @Shared(.protectionState) var protectionState: ProtectionState = .unprotected
    @Shared(.userCountry) var userCountry: String? = "PL"
    @Shared(.userIP) var userIP: String? = "123.456.789.0"
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

@available(iOS 17, *)
#Preview("resolving", traits: .sizeThatFitsLayout) {
    @Shared(.protectionState) var protectionState: ProtectionState = .resolving
    @Shared(.userCountry) var userCountry: String? = "PL"
    @Shared(.userIP) var userIP: String? = "123.456.789.0"
    ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
}

@available(iOS 17, *)
#Preview("protecting", traits: .sizeThatFitsLayout) {
    @Shared(.protectionState) var protectionState: ProtectionState = .protecting(country: "PL", ip: "123.456.789.0")
    return ConnectionStatusView(store: Store(initialState: .init()) {
        ConnectionStatusFeature()
    })
    .background(Color.black)
}
