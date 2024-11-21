//
//  Created on 25.05.23.
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

import Foundation
import SwiftUI

import ComposableArchitecture
import Dependencies

import Domain
import Home
import Theme
import Strings
import VPNAppCore
import SharedViews
import ProtonCoreUIFoundations

@available(iOS 17, *)
struct HomeConnectionCardView: View {
    @Dependency(\.locale) private var locale

    let store: StoreOf<HomeConnectionCardFeature>

    let model = ConnectionCardModel()

    private var accessibilityText: String {
        let countryName = store.presentedSpec.location.text(locale: locale)
        return model.accessibilityText(for: store.vpnConnectionStatus, countryName: countryName)
    }

    private var header: some View {
        HomeConnectionCardTitleView(store: .init(initialState: .init(), reducer: {
            HomeConnectionCardTitleFeature()
        }))
        .padding(.bottom, .themeSpacing8)
        .padding(.top, .themeSpacing24)
    }

    @ViewBuilder
    private var chevron: some View {
        if store.vpnConnectionStatus.connectionStatusAvailable {
            IconProvider.chevronRight
                .foregroundColor(Color(.icon, .weak))
        }
    }

    private var connectionButton: some View {
        Button {
            withAnimation(.linear) {
                switch store.vpnConnectionStatus {
                case .disconnected:
                    store.send(.delegate(.connect(store.presentedSpec)))
                case .connected:
                    store.send(.delegate(.disconnect))
                case .connecting:
                    store.send(.delegate(.disconnect))
                case .loadingConnectionInfo:
                    store.send(.delegate(.disconnect))
                case .disconnecting:
                    break
                }
            }
        } label: {
            Text(model.buttonText(for: store.vpnConnectionStatus))
        }
        .buttonStyle(ConnectButtonStyle(isDisconnected: store.vpnConnectionStatus == .disconnected))
    }

    @ViewBuilder
    private var changeServerButton: some View {
        WithPerceptionTracking {
            if store.showChangeServerButton {
                switch store.serverChangeAvailability ?? .available {
                case .available:
                    ChangeServerButtonLabel(sendAction: { _ = store.send($0) },
                                            changeServerAllowedDate: .distantPast)
                case let .unavailable(until, _, _):
                    ChangeServerButtonLabel(sendAction: { _ = store.send($0) },
                                            changeServerAllowedDate: until)
                }
            }
        }
    }

    private var connectionDetail: some View {
        Button {
            store.send(.delegate(.tapAction))
        } label: {
            HStack {
                ConnectionFlagInfoView(
                    intent: store.presentedSpec,
                    underMaintenance: false,
                    isPinned: false,
                    vpnConnectionActual: store.vpnConnectionStatus.actual,
                    withServerNumber: store.userTier.isFreeTier,
                    withDivider: false,
                    isConnected: false,
                    images: .coreImages
                )

                Spacer()

                chevron
            }
            .padding(.themeSpacing16)
        }
        .disabled(!store.vpnConnectionStatus.connectionStatusAvailable)
    }

    private var card: some View {
        VStack(spacing: 0) {
            connectionDetail

            connectionButton
                .padding(.horizontal, .themeSpacing16)
                .padding(.bottom, .themeSpacing16)
            changeServerButton
                .padding(.horizontal, .themeSpacing16)
                .padding(.bottom, .themeSpacing16)
        }
        .background(Color(.background, .weak))
        .themeBorder(color: Color(.border, .strong),
                     lineWidth: 1,
                     cornerRadius: .radius16)
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: .themeSpacing8) {
                header
                card
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityText)
            .accessibilityAction(named: Text(Localizable.actionConnect)) {
                store.send(.delegate(.connect(store.presentedSpec)))
            }
            .task {
                store.send(.watchConnectionStatus)
            }
        }
    }
}

fileprivate extension VPNConnectionStatus {
    var connectionStatusAvailable: Bool {
        guard case .connected = self else { return false }
        return true
    }
}

#if targetEnvironment(simulator)
#if compiler(>=6)
@available(iOS 18, *)
#Preview("Change Server Available",
         traits: .sizeThatFitsLayout,
                 .dependencies { $0.serverChangeAuthorizer = .availableValue }) {
    @Shared(.userTier) var userTier
    @Shared(.vpnConnectionStatus) var vpnConnectionStatus
    userTier = 0
    vpnConnectionStatus = .connected(.secureCoreCountryHop, nil)
    return HomeConnectionCardView(store: .init(initialState: .init(), reducer: {
            HomeConnectionCardFeature()
        }))
    .padding()
    .preferredColorScheme(.dark)
}

@available(iOS 18, *)
#Preview("Change Server Unavailable",
         traits: .sizeThatFitsLayout,
                 .dependencies { $0.serverChangeAuthorizer = .previewValue }) {
    @Shared(.userTier) var userTier
    @Shared(.vpnConnectionStatus) var vpnConnectionStatus
    userTier = 0
    vpnConnectionStatus = .connected(.secureCoreCountryHop, nil)
    return HomeConnectionCardView(store: .init(initialState: .init(), reducer: {
            HomeConnectionCardFeature()
        }))
    .padding()
    .preferredColorScheme(.dark)
}
#endif

@available(iOS 17, *)
#Preview("Free users", traits: .fixedLayout(width: 840, height: 300)) {
    cardPair(spec: .defaultFastest, userTier: 0)
        .padding()
        .preferredColorScheme(.dark)
}

@available(iOS 17, *)
#Preview("Standard", traits: .fixedLayout(width: 740, height: 1100)) {
    VStack {
        cardPair(spec: .defaultFastest)
        cardPair(spec: .specificCountry)
        cardPair(spec: .specificCity)
        cardPair(spec: .specificCityServer)
        cardPair(spec: .specificCountryServer)
    }
    .padding()
    .preferredColorScheme(.dark)
}

@available(iOS 17, *)
#Preview("Secure Core", traits: .fixedLayout(width: 740, height: 700)) {
    VStack(spacing: .themeSpacing24) {
        cardPair(spec: .secureCoreFastest)
        cardPair(spec: .secureCoreCountry)
        cardPair(spec: .secureCoreCountryHop)
    }
    .padding()
    .preferredColorScheme(.dark)
}

@available(iOS 17, *)
#Preview("Connection Features", traits: .fixedLayout(width: 740, height: 900)) {
    VStack(spacing: .themeSpacing24) {
        cardPair(spec: .defaultFastest.withAllFeatures())
        cardPair(spec: .specificCountry.withAllFeatures())
        cardPair(spec: .specificCity.withAllFeatures())
        cardPair(spec: .specificCityServer.withAllFeatures())
    }
    .padding()
    .preferredColorScheme(.dark)
}

@available(iOS 17, *)
fileprivate func cardPair(spec: ConnectionSpec, userTier: Int = 2) -> some View {
    return HStack(spacing: .themeSpacing24) {
        HomeConnectionCardView(store: .disconnectedStore(defaultConnection: spec, userTier: userTier))
        HomeConnectionCardView(store: .connectedStore(intentSpec: spec, userTier: userTier))
    }
}

extension HomeConnectionCardFeature.State {
    static func constant(status: VPNConnectionStatus, 
                         defaultConnection: ConnectionSpec,
                         userTier: Int) -> Self {
        var state = HomeConnectionCardFeature.State()
        state.$userTier = .constant(userTier)
        state.$vpnConnectionStatus = .constant(status)
        return state
    }
}

extension StoreOf<HomeConnectionCardFeature> {
    static func disconnectedStore(defaultConnection: ConnectionSpec, userTier: Int) -> Self {
        .init(initialState: .constant(status: .disconnected,
                                      defaultConnection: defaultConnection,
                                      userTier: userTier)) {
            HomeConnectionCardFeature()
        }
    }

    static func connectedStore(intentSpec: ConnectionSpec, userTier: Int) -> Self {
        .init(initialState: .constant(status: .connected(intentSpec, nil),
                                      defaultConnection: .defaultFastest,
                                      userTier: userTier)) {
            HomeConnectionCardFeature()
        }
    }
}
#endif
