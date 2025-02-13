//
//  Created on 2025-01-15.
//
//  Copyright (c) 2025 Proton AG
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
import WidgetKit
import VPNAppCore

import ComposableArchitecture

/// TODO: Revamp this view [VPNAPPL-2591]
public struct ConnectWidgetView : View {

    @Environment(\.widgetFamily) var widgetFamily

    @SharedReader(.vpnConnection) public var vpnConnection: String

    public var body: some View {
        VStack {
            switch widgetFamily {
            case .systemLarge:
                Image(.logoWithTitle)
            default:
                Image(.logoMarks)
            }
            Text(vpnConnection)
            Spacer()
            if vpnConnection == "Connected" {
                Button(intent: DisconnectFromVPNIntent()) {
                    Text("Disconnect")
                }
            } else {
                Button(intent: ConnectToVPNIntent()) {
                    Text("Connect")
                }
            }

        }
    }
}
