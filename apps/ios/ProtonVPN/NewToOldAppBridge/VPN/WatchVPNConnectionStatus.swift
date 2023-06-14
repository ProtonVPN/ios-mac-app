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

import Foundation
import ComposableArchitecture
import VPNShared
import vpncore
import PMLogger

private var appStateManager: AppStateManager! = DependencyContainer.shared.makeAppStateManager()

extension WatchAppStateChangesKey {

    static let watchAppDisplayStateChanges: @Sendable () async -> AsyncStream<VPNConnectionStatus> = {
        return NotificationCenter.default.notifications(named: .AppStateManager.displayStateChange).map({
            ($0.object as! AppDisplayState).vpnConnectionStatus
        }).eraseToStream()
    }

}

extension AsyncStream {
    init<Sequence: AsyncSequence>(_ sequence: Sequence) where Sequence.Element == Element {
        self.init {
            var iterator: Sequence.AsyncIterator?
            if iterator == nil {
                iterator = sequence.makeAsyncIterator()
            }
            return try? await iterator?.next()
        }
    }

    func eraseToStream() -> AsyncStream<Element> {
        AsyncStream(self)
    }
}

// MARK: - AppDisplayState -> VPNConnectionStatus

extension AppDisplayState {

    var vpnConnectionStatus: VPNConnectionStatus {
        let fakeSpecs = ConnectionSpec(location: .fastest, features: [])
        switch self {
        case .connected:
            return .connected(fakeSpecs)

        case .connecting:
            return .connecting(fakeSpecs)

        case .loadingConnectionInfo:
            return .loadingConnectionInfo(fakeSpecs)

        case .disconnecting:
            return .disconnecting(fakeSpecs)

        case .disconnected:
            return .disconnected
        }
    }
}
