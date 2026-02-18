//
//  Created on 10/02/2026 by Max Kupetskyi.
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
import PMLogger
import SharedErgonomics
import Strings
import Testing
@testable import tvos_app

@MainActor
struct LogsFeatureTests {
    @Test
    func loadsApplicationLogs() async {
        let store = TestStore(initialState: LogsFeature.State(logSource: .app)) {
            LogsFeature()
        } withDependencies: {
            $0.logContentProvider = .init(getLogData: { _ in
                TestLogContent(result: "app logs")
            })
        }
        store.exhaustivity = .off
        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.logsLoaded) {
            $0.isLoading = false
            $0.logs = "app logs"
        }
    }

    @Test
    func loadsWireguardLogs() async {
        let store = TestStore(initialState: LogsFeature.State(logSource: .wireguard)) {
            LogsFeature()
        } withDependencies: {
            $0.logContentProvider = .init(getLogData: { _ in
                TestLogContent(result: "wireguard logs")
            })
        }
        store.exhaustivity = .off
        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.logsLoaded) {
            $0.isLoading = false
            $0.logs = "wireguard logs"
        }
    }
}

private struct TestLogContent: LogContent {
    let result: String

    func loadContent(callback: @escaping (String) -> Void) {
        callback(result)
    }

    func loadContent() async -> String {
        result
    }
}
