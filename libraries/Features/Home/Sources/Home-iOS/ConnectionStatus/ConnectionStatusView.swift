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
import Domain
import HomeShared
import Localization
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

@MainActor
struct ConnectionStatusView: View {
    private static let maxContentWidth: CGFloat = 480

    @Bindable var store: StoreOf<ConnectionStatusFeature>
    /// Reports the height of the connection status view so that the backdrop can be properly framed.
    var onContentHeightChange: ((CGFloat) -> Void)?

    private static let headerHeight: CGFloat = 58
    private static let viewHeight: CGFloat = 200

    // `.killSwitchActive` never reaches these helpers, since `body` renders the KillSwitchBlockingBanner. Group its
    // case with `.unprotected`.
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
        case .authenticationRequired:
            "Authentication required"
        }
    }

    private func gradientColor(protectionState: ProtectionState) -> Color {
        switch protectionState {
        case .protected, .protectedSecureCore:
            Color(.background, .success)
        case .unprotected:
            Color(.background, .danger)
        case .authenticationRequired:
            Color(.background, .warning)
        case .protecting, .resolving, .killSwitchActive:
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
        case .protecting, .resolving, .killSwitchActive:
            ProgressView()
                .controlSize(.regular)
                .tint(.white)
        case .unprotected:
            IconProvider.lockOpenFilled2
                .styled(.danger)
                .accessibilityHidden(true)
        case .authenticationRequired:
            IconProvider.exclamationTriangleFilled
                .foregroundColor(Color(.icon, .warning))
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
            case .protecting, .resolving, .killSwitchActive:
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
            case .unprotected:
                IconProvider.lockOpenFilled2
                    .styled(.danger)
            case .authenticationRequired:
                IconProvider.exclamationTriangleFilled
                    .foregroundColor(Color(.icon, .warning))
            }
        }
    }

    var body: some View {
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
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // The lock and title, with content height reported so that the globe can be framed properly
                VStack(spacing: 0) {
                    titleView(protectionState: protectionState)
                        .frame(height: Self.headerHeight)
                    if let title = title(protectionState: protectionState) {
                        Text(title)
                            .font(.themeFont(.body1(.bold)))
                        Spacer()
                            .frame(height: .themeSpacing8)
                    }
                }
                .allowsHitTesting(false)
                ConnectionStatusBanner(store: store.scope(state: \.connectionStatusBanner, action: \.connectionStatusBanner))
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: .themeRadius8,
                            style: .continuous
                        )
                    )
                    .frame(maxWidth: Self.maxContentWidth)
                    .padding(.horizontal, .themeSpacing16)
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { onContentHeightChange?($0) }
        }
        // Fixed height in both modes so the tint gradient stays localized to the top band and fades out.
        // With no height the greedy gradient would fill the whole map.
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

#if DEBUG
    #Preview("protected", traits: .sizeThatFitsLayout) {
        @SharedReader(.protectionState) var protectionState: ProtectionState = .protected
        return ConnectionStatusView(store: Store(initialState: .init()) {
            ConnectionStatusFeature()
        })
    }

    #Preview("unprotected", traits: .sizeThatFitsLayout) {
        @SharedReader(.protectionState) var protectionState: ProtectionState = .unprotected
        @SharedReader(.userLocation) var userLocation: StoredUserLocation? =
            .measured(.init(ip: "123.456.789.0", country: "PL", isp: "Play"), at: .now)
        return ConnectionStatusView(store: Store(initialState: .init()) {
            ConnectionStatusFeature()
        })
    }

    #Preview("resolving", traits: .sizeThatFitsLayout) {
        @SharedReader(.protectionState) var protectionState: ProtectionState = .resolving
        @SharedReader(.userLocation) var userLocation: StoredUserLocation? =
            .measured(.init(ip: "123.456.789.0", country: "PL", isp: "Play"), at: .now)
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

    #Preview("protected", traits: .sizeThatFitsLayout) {
        @SharedReader(.protectionState) var protectionState: ProtectionState = .protected
        return ConnectionStatusView(store: Store(initialState: .init()) {
            ConnectionStatusFeature()
        })
        .background(Color.black)
    }
#endif
