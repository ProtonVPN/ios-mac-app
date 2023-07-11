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

@MainActor
final class SettingsTests: XCTestCase {

    func testChildFeaturePresentedWhenTapped() async throws {
        let store = TestStore(
            initialState: SettingsFeature.State(
                destination: .none,
                netShield: .off,
                killSwitch: .on,
                protocol: .init(protocol: .smartProtocol, reconnectionAlert: nil),
                theme: .auto
            ),
            reducer: SettingsFeature()
        )

        await store.send(.netShieldTapped, assert: { resultState in
            resultState.destination = .netShield
        })
    }

    func testChildFeatureModificationReflectedInParent() async throws {
        let store = TestStore(
            initialState: SettingsFeature.State(
                destination: .netShield,
                netShield: .on,
                killSwitch: .on,
                protocol: .init(protocol: .smartProtocol, reconnectionAlert: nil),
                theme: .auto),
            reducer: SettingsFeature()
        )

        await store.send(.netShield(.set(value: .off)), assert: { resultState in
            resultState.netShield = .off
        })
    }
}
