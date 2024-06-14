//
//  Created on 03/06/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Theme
import ComposableArchitecture
import Connection
import struct Domain.Server

struct CountryListItemView: View {
    let item: CountryListItem
    let isFocused: Bool
    @State var duration = inFocusDuration

    @Shared(.inMemory("connectionState")) var connectionState: Connection.ConnectionState?

    private static var outFocusDuration = 0.4
    private static var inFocusDuration = 0.1
    private let normalScale: CGFloat = 1
    private let focusedScale: CGFloat = 1.3

    var body: some View {
        VStack(spacing: 0) {
            SimpleFlagView(regionCode: item.code, flagSize: .tvListSize)
                .hoverEffect(.highlight)
            Spacer()
                .frame(height: 34)
            connectedLabel
        }
    }

    private var connectedLabel: some View {
        VStack(spacing: 0) {
            Text(verbatim: item.name)
                .font(.body)
            Spacer()
                .frame(height: .themeSpacing16)
            switch connectionState ?? .disconnected {
            case .connected:
                HStack(spacing: .themeSpacing12) {
                    Text("Connected", comment: "VPN connection state")
                        .font(.caption)
                        .foregroundStyle(Asset.vpnGreen.swiftUIColor)
                    ConnectedCircleView()
                }
                .opacity(item.code == connectedCode ? 1 : 0)
            case .connecting:
                HStack(spacing: .themeSpacing12) {
                    Text("Connecting", comment: "VPN connection state")
                        .font(.caption)
                        .foregroundStyle(Color(.text, .weak))
                    ProgressView()
                }
                .opacity(item.code == connectedCode ? 1 : 0)
            default:
                EmptyView()
            }
        }
        // This scaleEffect aims to mimic ".hoverEffect(.highlight)"
        .scaleEffect(isFocused ? focusedScale : normalScale)
        .animation(.easeOut(duration: duration), value: isFocused)
        .onChange(of: isFocused) { _, newValue in
            duration = newValue ? Self.outFocusDuration : Self.inFocusDuration
        }
    }

    private var connectedCode: String? {
        switch connectionState {
        case .connected(let server):
            return server.logical.entryCountryCode
        case .connecting:
//            return code
            return nil
        default:
            return nil
        }
    }
}
