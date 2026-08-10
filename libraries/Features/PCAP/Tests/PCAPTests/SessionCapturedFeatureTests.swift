//
//  Created on 2026-06-26 by Pawel Jurczyk.
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
import Connection
@testable import PCAPShared
import Testing

@Suite("Session Captured Feature Tests", .serialized)
@MainActor
struct SessionCapturedFeatureTests {
    @Test
    func `done tapped presents discard alert`() async {
        var cleanupCalled = false
        let store = TestStore(initialState: SessionCapturedFeature.State()) {
            SessionCapturedFeature()
        } withDependencies: {
            $0.packetCaptureClient = .stub(onCleanup: {
                cleanupCalled = true
            })
        }
        await store.send(.doneTapped) {
            $0.alert = SessionCapturedFeature.discardFileAlert
        }

        await store.send(.alert(.presented(.cancel))) {
            $0.alert = nil
        }
        #expect(!cleanupCalled)

        await store.send(.doneTapped) {
            $0.alert = SessionCapturedFeature.discardFileAlert
        }

        await store.send(.alert(.presented(.discardFile))) {
            $0.alert = nil
        }
        #expect(cleanupCalled)
    }
}
