//
//  ConnectingOverlayViewModelTests.swift
//  ProtonVPN - Created on 2021-04-19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Dependencies
import Domain
@testable import ProtonVPN
import Sharing
import Strings
import Testing
import VPNAppCore

@MainActor
struct ConnectingOverlayViewModelTests {
    @Shared(.vpnConnectionStatus) var vpnConnectionStatus

    init() {
        $vpnConnectionStatus.withLock { $0 = .disconnected }
    }

    @Test
    func whenStatusChangesDelegateIsInformed() async {
        let viewModel = ConnectingOverlayViewModel(cancellation: {})

        await confirmation("Delegate stateChanged called") { stateChanged in
            let delegate = OverlayViewModelDelegateMock {
                stateChanged()
            }
            viewModel.delegate = delegate
            $vpnConnectionStatus.withLock { $0 = .connected(.defaultFastest, nil) }
            try? await Task.sleep(for: .milliseconds(50))
            withExtendedLifetime(delegate) {}
        }
    }

    @Test
    func afterConnectedStatusViewModelStopsChanging() async {
        let viewModel = ConnectingOverlayViewModel(cancellation: {})

        await confirmation("Delegate called only once", expectedCount: 1) { stateChanged in
            let delegate = OverlayViewModelDelegateMock {
                stateChanged()
            }
            viewModel.delegate = delegate
            $vpnConnectionStatus.withLock { $0 = .connected(.defaultFastest, .mock()) }
            $vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            $vpnConnectionStatus.withLock { $0 = .disconnected }
            try? await Task.sleep(for: .milliseconds(50))
            _ = delegate
        }
    }

    @Test
    func whenStatusIsResolvingCancelButtonIsShown() {
        let viewModel = ConnectingOverlayViewModel(cancellation: {})
        $vpnConnectionStatus.withLock { $0 = .resolving(.defaultFastest, nil) }

        let buttons = viewModel.buttons
        #expect(buttons.count == 1)
        #expect(buttons[0].0 == Localizable.cancel)
    }

    @Test
    func whenStatusIsConnectingCancelButtonIsShown() {
        let viewModel = ConnectingOverlayViewModel(cancellation: {})
        $vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }

        let buttons = viewModel.buttons
        #expect(buttons.count == 1)
        #expect(buttons[0].0 == Localizable.cancel)
    }

    @Test
    func whenStatusIsConnectedDoneButtonIsShown() {
        let viewModel = ConnectingOverlayViewModel(cancellation: {})
        $vpnConnectionStatus.withLock { $0 = .connected(.defaultFastest, nil) }

        let buttons = viewModel.buttons
        #expect(buttons.count == 1)
        #expect(buttons[0].0 == Localizable.done)
    }

    @Test
    func whenStatusIsDisconnectingCancelButtonIsShown() {
        let viewModel = ConnectingOverlayViewModel(cancellation: {})
        $vpnConnectionStatus.withLock { $0 = .disconnecting(.defaultFastest, nil) }

        let buttons = viewModel.buttons
        #expect(buttons.count == 1)
        #expect(buttons[0].0 == Localizable.cancel)
    }

    @Test
    func whenStatusIsDisconnectedCancelButtonIsShown() {
        let viewModel = ConnectingOverlayViewModel(cancellation: {})
        $vpnConnectionStatus.withLock { $0 = .disconnected }

        let buttons = viewModel.buttons
        #expect(buttons.count == 1)
        #expect(buttons[0].0 == Localizable.cancel)
    }
}

private final class OverlayViewModelDelegateMock: OverlayViewModelDelegate {
    var stateChangedCalled: () -> Void

    init(stateChangedCalled: @escaping () -> Void) {
        self.stateChangedCalled = stateChangedCalled
    }

    func stateChanged() {
        stateChangedCalled()
    }
}
