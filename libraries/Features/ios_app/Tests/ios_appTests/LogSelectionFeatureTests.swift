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

    @Test("Download ATV logs sets share URL")
    func downloadAppleTVLogsSuccessSetsShareURL() async {
        let expectedURL = URL(string: "file:///tmp/ProtonVPN_AppleTV.log")!
        let store = TestStore(initialState: LogSelectionFeature.State()) {
            LogSelectionFeature()
        } withDependencies: {
            $0.appleTVLogsDownloadClient.download = { expectedURL }
        }

        await store.send(.rowTapped(.downloadAppleTVLogs))
        await store.receive(\.downloadResponse) {
            $0.shareLogsURL = expectedURL
        }
    }

    @Test("Download ATV logs failure sets alert message")
    func downloadAppleTVLogsFailureSetsAlertMessage() async {
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
            $0.alertMessage = "Download failed in test"
        }
    }

    @Test("Dismissing logs destination cleans temporary file")
    func dismissingLogsDestinationCleansTemporaryFile() async throws {
        let tempFile = URL.temporaryDirectory.appendingPathComponent("LogSelectionFeatureTests-cleanup.log")
        try "cleanup".write(to: tempFile, atomically: true, encoding: .utf8)

        let logsState = LogsViewFeature.State(
            logSource: .app,
            pendingShareURL: tempFile,
            temporaryShareFileURL: tempFile
        )

        var initialState = LogSelectionFeature.State()
        initialState.destination = .logs(logsState)
        let store = TestStore(initialState: initialState) {
            LogSelectionFeature()
        }

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }

        #expect(FileManager.default.fileExists(atPath: tempFile.path) == false)
    }

    @Test("Child logs share action sets parent share URL")
    func childLogsShareActionSetsParentShareURL() async {
        let fileURL = URL.temporaryDirectory.appendingPathComponent("LogSelectionFeatureTests-share.log")
        var initialState = LogSelectionFeature.State()
        initialState.destination = .logs(.init(logSource: .app))

        let store = TestStore(initialState: initialState) {
            LogSelectionFeature()
        }

        await store.send(.destination(.presented(.logs(.shareFilePrepared(fileURL))))) {
            $0.shareLogsURL = fileURL
        }
    }
}
