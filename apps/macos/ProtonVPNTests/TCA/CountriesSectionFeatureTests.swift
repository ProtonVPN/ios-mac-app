//
//  Created on 12/02/2024.
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

import ComposableArchitecture
import Ergonomics
import Foundation
@testable import ProtonVPN
import Testing

@MainActor
struct CountriesSectionFeatureTests {
    @Test
    func `onAppear with started quick settings only dismisses details`() async {
        // The quick settings state reads `VPNFeatureFlagType.portForwarding` while it is built.
        let store = TestStore(initialState: CountriesSectionFeature.State(
            hasStartedQuickSettings: true
        )) {
            CountriesSectionFeature()
        } withDependencies: {
            $0.featureFlags = .enabling()
        }

        await store.send(.onAppear)
        await store.receive(\.quickSettings.dismissDetails)
    }
}
