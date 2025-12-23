//
//  Created on 2023-05-11.
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

@testable import BugReportShared
import ComposableArchitecture
import Foundation
import Testing

@Suite
@MainActor
struct ResultTests {
    @Test("Pressing finish calls the delegate")
    func pressingFinishCallsTheDelegate() async throws {
        var delegateCalled = false

        let store = TestStore(
            initialState: BugReportResultFeature.State(error: nil),
            reducer: { BugReportResultFeature() },
            withDependencies: {
                $0.finishBugReport = {
                    Task { @MainActor in
                        delegateCalled = true
                    }
                }
            }
        )

        await store.send(.finish)

        // Give the async operation a moment to complete
        try await Task.sleep(for: .milliseconds(10))

        #expect(delegateCalled == true)
    }

    @Test("Pressing troubleshooting shows troubleshoot sheet")
    func pressingTroubleshootingOpensTroubleshoot() async throws {
        let store = TestStore(
            initialState: BugReportResultFeature.State(error: nil),
            reducer: { BugReportResultFeature() }
        )

        await store.send(.setSheet(isPresented: true)) {
            $0.isTroubleshootPresented = true
            $0.troubleshoot = .init()
        }

        await store.send(.troubleshoot(.closeButtonTapped))
        await store.receive(\.setSheet) {
            $0.isTroubleshootPresented = false
            $0.troubleshoot = nil
        }
    }
}
