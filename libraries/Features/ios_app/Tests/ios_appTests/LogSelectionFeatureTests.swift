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
import Testing

@Suite("Log Selection Feature Tests")
@MainActor
struct LogSelectionFeatureTests {
    @Test("Selecting log source sets logs destination")
    func selectingLogSourceSetsLogsDestination() async {
        let store = TestStore(initialState: LogSelectionFeature.State()) {
            LogSelectionFeature()
        }

        await store.send(.rowTapped(.logSource(.app))) {
            $0.destination = .logs(.init(logSource: .app))
        }
    }

    @Test("Download ATV logs sets share logs destination")
    func downloadAppleTVLogsSuccessSetsShareLogsDestination() async {
        let expectedURL = URL(string: "file:///tmp/ProtonVPN_AppleTV.log")!
        let store = TestStore(initialState: LogSelectionFeature.State()) {
            LogSelectionFeature()
        } withDependencies: {
            $0.appleTVLogsDownloadClient.download = { expectedURL }
        }

        await store.send(.rowTapped(.downloadAppleTVLogs))
        await store.receive(\.downloadResponse) {
            $0.destination = .shareLogs(url: expectedURL)
        }
    }

    @Test("Download ATV logs failure sets alert destination")
    func downloadAppleTVLogsFailureSetsAlertDestination() async {
        enum TestError: LocalizedError {
            case failed
            var errorDescription: String? { "Download failed in test" }
        }

        let store = TestStore(initialState: LogSelectionFeature.State()) {
            LogSelectionFeature()
        } withDependencies: {
            $0.appleTVLogsDownloadClient.download = { throw TestError.failed }
        }

        await store.send(.rowTapped(.downloadAppleTVLogs))
        await store.receive(\.downloadResponse) {
            $0.destination = .logsDownloadFailedAlert(message: "Download failed in test")
        }
    }
}
