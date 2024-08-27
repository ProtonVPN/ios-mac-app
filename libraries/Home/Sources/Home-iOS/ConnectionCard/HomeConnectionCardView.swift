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
    static let maxWidth: CGFloat = 736
    @Dependency(\.locale) private var locale

    let model = ConnectionCardModel()

    let item: RecentConnection
    var vpnConnectionStatus: VPNConnectionStatus
    let sendAction: HomeFeature.ActionSender

    init(item: RecentConnection,
         vpnConnectionStatus: VPNConnectionStatus,
         sendAction: @escaping HomeFeature.ActionSender = { _ in }) {
        self.item = item
        self.vpnConnectionStatus = vpnConnectionStatus
        self.sendAction = sendAction
    }

    private var accessibilityText: String {
        let countryName = item.connection.location.text(locale: locale)
        return model.accessibilityText(for: vpnConnectionStatus, countryName: countryName)
    }

    private var header: some View {
        HomeConnectionCardTitleView(connectionStatus: vpnConnectionStatus,
                                    isFreeUser: false, // TODO: [redesign] add info about free user
                                    hasRecents: false, // TODO: [redesign] add info about recents
                                    changingServer: false) // TODO: [redesign] add info about changing server
        .padding(.bottom, .themeSpacing8)
        .padding(.top, .themeSpacing24)
    }

    var card: some View {
        VStack {
            HStack {
                ConnectionFlagInfoView(intent: item.connection,
                                       vpnConnectionActual: vpnConnectionStatus.actual,
                                       withDivider: false)
                Spacer()

                if vpnConnectionStatus.connectionStatusAvailable {
                    Button() {
                        sendAction(.showConnectionDetails)
                    } label: {
                        IconProvider.chevronRight
                    }
                    .foregroundColor(Color(.icon, .weak))
                }
            }
            .padding()

            Button {
                withAnimation(.easeInOut) {
                    switch vpnConnectionStatus {
                    case .disconnected:
                        sendAction(.connect(item.connection))
                    case .connected:
                        sendAction(.disconnect)
                    case .connecting:
                        sendAction(.disconnect)
                    case .loadingConnectionInfo:
                        sendAction(.disconnect)
                    case .disconnecting:
                        break
                    }
                }
            } label: {
                Text(model.buttonText(for: vpnConnectionStatus))
            }
            .buttonStyle(ConnectButtonStyle(isDisconnected: vpnConnectionStatus == .disconnected))
        }
        .background(Color(.background, .weak))
        .themeBorder(color: Color(.border, .strong),
                     lineWidth: 1,
                     cornerRadius: .radius16)
    }

    public var body: some View {
        VStack(spacing: .themeSpacing8) {
            header
            card
        }
        .frame(maxWidth: Self.maxWidth)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: Text(Localizable.actionConnect)) {
            sendAction(.connect(item.connection))
        }
    }
}

fileprivate extension VPNConnectionStatus {
    var connectionStatusAvailable: Bool {
        guard case .connected = self else { return false }
        return true
    }
}

@available(iOS 17, *)
#Preview("Standard", traits: .fixedLayout(width: 740, height: 1100)) {
    HStack(spacing: .themeSpacing24) {
        cardSet(status: .disconnected)
        cardSet(status: .connected(.mock(), .mock()))
    }
    .padding()
    .preferredColorScheme(.dark)
}

@available(iOS 17, *)
#Preview("Secure Core", traits: .fixedLayout(width: 740, height: 700)) {
    HStack(spacing: .themeSpacing24) {
        secureCoreCardSet(status: .disconnected)
        secureCoreCardSet(status: .connected(.mock(), .mock()))
    }
    .padding()
    .preferredColorScheme(.dark)
}

@available(iOS 17, *)
#Preview("Connection Features", traits: .fixedLayout(width: 740, height: 900)) {
    HStack(spacing: .themeSpacing24) {
        featuresCardSet(status: .disconnected)
        featuresCardSet(status: .connected(.mock(), .mock().withAllFeatures()))
    }
    .padding()
    .preferredColorScheme(.dark)
}

@available(iOS 17, *)
fileprivate func featuresCardSet(status: VPNConnectionStatus) -> some View {
    VStack {
        HomeConnectionCardView(item: .defaultFastest.withAllFeatures(),
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionRegion.withAllFeatures(),
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionCity.withAllFeatures(),
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionCity.withServer(server: 12).withAllFeatures(),
                               vpnConnectionStatus: status)
    }
}

@available(iOS 17, *)
fileprivate func secureCoreCardSet(status: VPNConnectionStatus) -> some View {
    VStack {
        HomeConnectionCardView(item: .connectionSecureCoreFastest,
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionSecureCoreFastestHop,
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionSecureCore,
                               vpnConnectionStatus: status)
    }
}

@available(iOS 17, *)
fileprivate func cardSet(status: VPNConnectionStatus) -> some View {
    VStack {
        HomeConnectionCardView(item: .defaultFastest,
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionRegion,
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionCity,
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .connectionCity.withServer(server: 30),
                               vpnConnectionStatus: status)
        HomeConnectionCardView(item: .previousFreeConnection,
                               vpnConnectionStatus: status)
    }
}

extension ConnectionSpec {
    static func mock() -> Self {
        .init(location: .fastest,
              features: [])
    }
}
