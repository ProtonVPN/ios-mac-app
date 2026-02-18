//
//  Created on 12/02/2026 by Max Kupetskyi.
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
import Foundation
@testable import ios_app
import PMLogger
import Strings
import Testing

@Suite("Logs View Feature Tests")
@MainActor
struct LogsViewFeatureTests {
    @Test("Loading logs on view did load updates state")
    func onViewDidLoadLoadsLogs() async {
        let store = TestStore(initialState: LogsViewFeature.State(logSource: .app)) {
            LogsViewFeature()
        } withDependencies: {
            $0.logContentProvider = .init(getLogData: { _ in
                TestLogContent(result: "app logs from test")
            })
        }

        await store.send(.onViewDidLoad)
        await store.receive(\.logsLoaded) {
            $0.logs = "app logs from test"
        }
    }

    @Test("Share prepares temporary file and pending share URL")
    func shareTappedPreparesFile() async {
        let store = TestStore(initialState: LogsViewFeature.State(logSource: .app, logs: "share me")) {
            LogsViewFeature()
        }

        await store.send(.shareTapped)
        await store.receive(\.shareFilePrepared)
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
