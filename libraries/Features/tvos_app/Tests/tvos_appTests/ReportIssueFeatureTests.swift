//
//  Created on 23/02/2026 by Max Kupetskyi.
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
import PMLogger
import ProtonCoreAPIClient
import Testing
@testable import tvos_app
import VPNShared

@MainActor
struct ReportIssueFeatureTests {
    @Test
    func onAppearAutofillsEmailAndUsername() async {
        let keychain = MockAuthKeychain()
        keychain.setMockUsername("tvos-user")

        let store = TestStore(initialState: ReportIssueFeature.State()) {
            ReportIssueFeature()
        } withDependencies: {
            $0.authKeychain = keychain
        }

        await store.send(.onAppear) {
            $0.email = ""
            $0.username = "tvos-user"
        }
    }

    @Test
    func sendReportWithLogsAttachesTemporaryFile() async {
        let sentReport = LockIsolated<ReportBug?>(nil)
        let removedFileURL = LockIsolated<URL?>(nil)

        let initialState = ReportIssueFeature.State(
            email: "user@example.com",
            username: "username",
            whatAreYouTryingToDo: "Connect to VPN",
            whatWentWrong: "Connection times out",
            sendErrorLogs: true
        )

        let store = TestStore(initialState: initialState) {
            ReportIssueFeature()
        } withDependencies: {
            $0.logContentProvider = .init(getLogData: { _ in
                TestLogContent(result: "app logs")
            })
            $0.fileManagerClient.removeItem = { url in removedFileURL.setValue(url) }
            $0.fileManagerClient.fileExists = { _ in true }
            $0.reportIssueAPIClient = .init(send: { report in
                sentReport.setValue(report)
            })
        }

        await store.send(.sendReportTapped) {
            $0.isSending = true
        }
        await store.receive(\.sendReportResponse) {
            $0.isSending = false
            $0.alert = AlertState {
                TextState("Report sent")
            } actions: {
                ButtonState(action: .dismiss) {
                    TextState("OK")
                }
            }
            $0.whatAreYouTryingToDo = ""
            $0.whatWentWrong = ""
        }

        #expect(sentReport.value?.files.count == 1)
        #expect(sentReport.value?.files.first?.lastPathComponent == "ProtonVPN-tvOS-report.log")
        #expect(removedFileURL.value?.lastPathComponent == "ProtonVPN-tvOS-report.log")
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
