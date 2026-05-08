//
//  Created on 2022-07-26.
//
//  Copyright (c) 2022 Proton AG
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
import Foundation
@testable import ProtonVPN
import Testing

struct SystemExtensionsServiceReducerTests {
    @Test("install emits approval once and then completion")
    func installEmitsApprovalAndCompletion() async {
        let store = TestStore(initialState: SystemExtensionsServiceReducer.State()) {
            SystemExtensionsServiceReducer()
        }

        await store.send(.startInstall(userInitiated: true, forceUpgrade: false, includedTypes: [.wireGuard])) {
            $0.currentOperation = .install
            $0.pendingTypes = [.wireGuard]
        }
        await store.send(.requestTransitioned(type: .wireGuard, state: .userActionRequired)) {
            $0.states[.wireGuard] = .userActionRequired
            $0.approvalRequiredTypes = [.wireGuard]
            $0.lastNotifiedApprovalTypes = [.wireGuard]
        }
        await store.receive(\.delegate.approvalRequired)

        await store.send(.requestTransitioned(type: .wireGuard, state: .succeeded(.completed))) {
            $0.states[.wireGuard] = .succeeded(.completed)
            $0.pendingTypes = []
        }
        await store.receive(\.delegate.installCompleted)
        await store.receive(\.clearCurrentOperation) {
            $0.currentOperation = nil
            $0.pendingTypes = []
            $0.states = [:]
            $0.approvalRequiredTypes = []
            $0.lastNotifiedApprovalTypes = []
        }
    }

    @Test("uninstall emits completion on terminal state")
    func uninstallEmitsCompletionOnTerminalState() async {
        let store = TestStore(initialState: SystemExtensionsServiceReducer.State()) {
            SystemExtensionsServiceReducer()
        }

        await store.send(.startUninstall(userInitiated: false, forceUpgrade: false, includedTypes: [.wireGuard])) {
            $0.currentOperation = .uninstall
            $0.pendingTypes = [.wireGuard]
        }
        await store.send(.requestTransitioned(type: .wireGuard, state: .succeeded(.completed))) {
            $0.states[.wireGuard] = .succeeded(.completed)
            $0.pendingTypes = []
        }
        await store.receive(\.delegate.uninstallCompleted)
        await store.receive(\.clearCurrentOperation) {
            $0.currentOperation = nil
            $0.pendingTypes = []
            $0.states = [:]
            $0.approvalRequiredTypes = []
            $0.lastNotifiedApprovalTypes = []
        }
    }
}
