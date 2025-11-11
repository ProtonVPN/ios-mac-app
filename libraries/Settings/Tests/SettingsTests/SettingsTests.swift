//
//  Created on 18/06/2023.
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

import XCTest

import ComposableArchitecture

@testable import Settings
@testable import SettingsShared

@MainActor
final class SettingsTests: XCTestCase {
    func testChildFeaturePresentedWhenTapped() async throws {
        let store = TestStore(
            initialState: SettingsFeature.State(
                netShield: .off,
                killSwitch: .on,
                protocolSettings: .init(protocol: .smartProtocol, vpnConnectionStatus: .disconnected, reconnectionAlert: nil),
                theme: .auto
            )) {
                SettingsFeature()
            }

        await store.send(.netShieldTapped) {
            $0.path.append(.netShield(NetShieldSettingsFeature.State.off))
        }
    }

    func testChildFeatureModificationReflectedInParent() async throws {
        let store = TestStore(
            initialState: SettingsFeature.State(
                path: StackState(
                    [.netShield(NetShieldSettingsFeature.State.on)]
                ),
                netShield: .on,
                killSwitch: .on,
                protocolSettings: .init(protocol: .smartProtocol, vpnConnectionStatus: .disconnected, reconnectionAlert: nil),
                theme: .auto
            )) {
                SettingsFeature()
            }

        await store.send(.path(.element(id: 0, action: .netShield(.set(value: .off))))) {
            $0.path[id: 0, case: \.netShield] = .off
        }
    }
}
