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

import XCTest
import ComposableArchitecture
@testable import BugReport

@MainActor
final class ResultTests: XCTestCase {

    func testPressingFinishCallsTheDelegate() async throws {
        let expectationDelegateIsCalled = XCTestExpectation(description: "Delegate has to be called")

        let store = TestStore(
            initialState: BugReportResultFeature.State(error: nil),
            reducer: { BugReportResultFeature() },
            withDependencies: {
                $0.finishBugReport = {
                    expectationDelegateIsCalled.fulfill()
                }
            }
        )

        await store.send(.finish)

        await fulfillment(of: [expectationDelegateIsCalled], timeout: 0.2)
    }

    func testPressingTroubleshootingCallsTheDelegate() async throws {
        let expectationDelegateIsCalled = XCTestExpectation(description: "Delegate has to be called")

        let store = TestStore(
            initialState: BugReportResultFeature.State(error: nil),
            reducer: { BugReportResultFeature() },
            withDependencies: {
                $0.troubleshoot = {
                    expectationDelegateIsCalled.fulfill()
                }
            }
        )

        await store.send(.troubleshoot)

        await fulfillment(of: [expectationDelegateIsCalled], timeout: 0.2)
    }

}
