//
//  Created on 2023-06-16.
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

#if targetEnvironment(simulator)

import Foundation
import VPNShared
import vpncore

/// Allows "connecting" to VPN on a simulator by faking VPN connection status
///
/// Usage:
/// .dependency(\.connectToVPN, SimulatorHelper.shared.connect)
/// .dependency(\.disconnectVPN, SimulatorHelper.shared.disconnect)
///
class SimulatorHelper {

    public static var shared = SimulatorHelper()

    private var status: VPNConnectionStatus = .disconnected {
        didSet {
            NotificationCenter.default.post(name: .AppStateManager.displayStateChange, object: status.appDisplayState)
        }
    }

    private var targetStatus: VPNConnectionStatus?

    private let queue: DispatchQueue = DispatchQueue.main

    // MARK: - Connect

    var connect: @Sendable (ConnectionSpec) -> Void {
        return { specs in
            switch self.status {
            case .disconnected:
                self.switchToConnected(specs)

            default:
                assert(false, "Called connect on wrong state: \(self.status)")
            }
        }
    }

    private func switchToConnected(_ specs: ConnectionSpec) {
        targetStatus = .connected(specs)
        queue.async {
            self.status = .connecting(specs)
        }
        queue.asyncAfter(deadline: .now() + .seconds(2), execute: {
            self.status = self.targetStatus!
        })
    }

    // MARK: - Connect

    var disconnect: @Sendable () -> Void {
        return {
            switch self.status {
            case .connected(let specs):
                self.switchToDisconnected(specs)

            case .connecting(let specs):
                self.switchToDisconnected(specs, delay: 0)

            default:
                assert(false, "Called connect on wrong state: \(self.status)")
            }
        }
    }

    private func switchToDisconnected(_ specs: ConnectionSpec, delay: Int = 1) {
        targetStatus = .disconnected
        queue.async {
            self.status = .disconnecting(specs)
        }
        queue.asyncAfter(deadline: .now() + .seconds(delay), execute: {
            self.status = self.targetStatus!
        })
    }

}

// MARK: - VPNConnectionStatus -> AppDisplayState

extension VPNConnectionStatus {
    var appDisplayState: AppDisplayState {
        switch self {
        case .disconnected:
            return .disconnected
        case .connected:
            return .connected
        case .connecting:
            return .connecting
        case .loadingConnectionInfo:
            return .loadingConnectionInfo
        case .disconnecting:
            return .disconnecting
        }
    }
}

#endif
