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

import Domain
import VPNAppCore
import LegacyCommon

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
            case .disconnected, .connected:
                let propertyManager = Container.sharedContainer.makePropertiesManager()
                propertyManager.lastConnectionIntent = specs

                self.switchToConnected(specs)
            case .connecting:
                self.switchToDisconnected(specs, delay: 0, completed: {
                    self.switchToConnected(specs)
                })
            default:
                log.assertionFailure("Called connect on wrong state: \(self.status)")
            }
        }
    }

    private func switchToConnected(_ specs: ConnectionSpec) {
        targetStatus = .connected(specs, specs.actualConnection)
        queue.async {
            self.status = .connecting(specs, nil)
        }
        queue.asyncAfter(deadline: .now() + .seconds(2), execute: {
            self.status = self.targetStatus!
        })
    }

    // MARK: - Connect

    var disconnect: @Sendable () -> Void {
        return {
            switch self.status {
            case .connected(let specs, _):
                self.switchToDisconnected(specs)

            case .connecting(let specs, _):
                self.switchToDisconnected(specs, delay: 0)

            default:
                log.assertionFailure("Called connect on wrong state: \(self.status)")
            }
        }
    }

    private func switchToDisconnected(_ specs: ConnectionSpec, delay: Int = 1, completed: (() -> Void)? = nil) {
        targetStatus = .disconnected
        queue.async {
            self.status = .disconnecting(specs, specs.actualConnection)
        }
        queue.asyncAfter(deadline: .now() + .seconds(delay), execute: {
            self.status = self.targetStatus!
            completed?()
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

// MARK: - VPNConnectionActual -> ConnectionSpec

extension ConnectionSpec {
    var actualConnection: VPNConnectionActual {
        VPNConnectionActual(
            serverModelId: "1",
            serverIPId: "2",
            vpnProtocol: .ike,
            natType: .moderateNAT,
            safeMode: nil,
            feature: .zero,
            serverName: "Server#123",
            country: "Country",
            city: "City"
        )
    }
}

#endif
