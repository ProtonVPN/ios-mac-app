//
//  Created on 11/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import NATPMPUI
import Strings
import SwiftUI
import Theme

/// Hosts the header at the top of the sidebar.
final class HeaderHostingController: NSHostingController<HeaderView> {
    required init(store: StoreOf<HeaderFeature>) {
        super.init(rootView: HeaderView(store: store))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    override func loadView() {
        view.translatesAutoresizingMaskIntoConstraints = false
    }
}

struct HeaderView: View {
    @Bindable var store: StoreOf<HeaderFeature>

    var body: some View {
        VStack(spacing: 0) {
            details
            Spacer(minLength: Dimensions.contentSpacing)
            buttons
        }
        .padding(.vertical, Dimensions.contentInsetVertical)
        .padding(.horizontal, Dimensions.contentInsetHorizontal)
        .frame(minHeight: Dimensions.minimumHeight)
        .background(FlagBackdrop(countryCode: store.connectedCountryCode))
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Dimensions.contentSpacing) {
            if store.showsKillSwitchIcon {
                Theme.Asset.advancedKs.swiftUIImage
                    .resizable()
                    .frame(.square(Dimensions.killSwitchIconSize))
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: Dimensions.stackSpacing) {
                HeaderTitleView(title: store.title)
                Spacer(minLength: Dimensions.stackSpacing)
                if let bell = store.bell {
                    AnnouncementsBellButton(bell: bell) { store.send(.announcementsBellTapped) }
                }
            }
            .frame(minHeight: Dimensions.headerRowHeight, alignment: .leading)

            VStack(alignment: .leading, spacing: Dimensions.stackSpacing) {
                HeaderAddressRow(addressLine: store.addressLine, load: store.serverLoad)
                HeaderSpeedRow(store: store)
                if let mappedPort = store.mappedPort {
                    StatusPortView(portNumber: mappedPort)
                }
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: Dimensions.stackSpacing) {
            HeaderConnectButton(kind: store.connectButtonKind) { store.send(.quickConnectTapped) }
            if store.showsChangeServer {
                HeaderChangeServerButton(allowedDate: store.changeServerAllowedDate) {
                    store.send(.changeServerTapped)
                }
            }
        }
    }

    private enum Dimensions {
        static let minimumHeight: CGFloat = 200
        static let contentInsetVertical: CGFloat = 24
        static let contentInsetHorizontal: CGFloat = 40
        static let contentSpacing: CGFloat = 16
        static let stackSpacing: CGFloat = 8
        static let headerRowHeight: CGFloat = 24
        static let killSwitchIconSize: CGFloat = 24
    }
}

/// The protocol in use and the transfer rate, which arrives once a second while connected.
///
/// The rate is read here rather than in `HeaderView`, so a new sample only runs this row's body. Read
/// from `HeaderView` it would run the whole header's body every second, and every text and icon in it
/// asks the theme for a color.
private struct HeaderSpeedRow: View {
    let store: StoreOf<HeaderFeature>

    var body: some View {
        HeaderProtocolRow(vpnProtocolName: store.vpnProtocolName, bitrate: store.bitrate)
    }
}

/// The bell that opens the current offer, with a dot while the offer is unread.
private struct AnnouncementsBellButton: View {
    let bell: HeaderFeature.Bell
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
                .frame(.square(Dimensions.size))
                .overlay(alignment: .topTrailing) {
                    if bell.hasUnread {
                        Circle()
                            .fill(Color(.background, .info))
                            .frame(.square(Dimensions.badgeSize))
                    }
                }
        }
        .buttonStyle(.plain)
        .linkPointer(isEnabled: true)
        .help(bell.tooltip ?? "")
    }

    @ViewBuilder
    private var icon: some View {
        if let iconURL = bell.iconURL {
            AsyncImage(url: iconURL) { image in
                image.resizable()
            } placeholder: {
                fallbackIcon
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Theme.Asset.Icons.bell.swiftUIImage
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(Color(.icon))
    }

    private enum Dimensions {
        static let size: CGFloat = 24
        static let badgeSize: CGFloat = 6
    }
}
