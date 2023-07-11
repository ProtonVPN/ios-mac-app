//
//  Created on 18/05/2023.
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

import SwiftUI

import ComposableArchitecture

import Settings
import Settings_iOS
import VPNAppCore

@main
struct SettingsSampleApp: App {
    @State var vpnConnectionStatus: VPNConnectionStatus = .connected(.init(location: .fastest, features: Set()), .mock())

    var body: some Scene {
        WindowGroup {
            SettingsView(store: Store(
                initialState: SettingsFeature.State(
                    destination: .protocol,
                    netShield: .on,
                    killSwitch: .off,
                    protocol: .init(protocol: .smartProtocol, vpnConnectionStatus: .disconnected, reconnectionAlert: nil),
                    theme: .light
                ),
                reducer: SettingsFeature()
                    ._printChanges()
                    .dependency(\.settingsStorage, SettingsStorage(setConnectionProtocol: { _ in }))
            ))
        }
    }
}
