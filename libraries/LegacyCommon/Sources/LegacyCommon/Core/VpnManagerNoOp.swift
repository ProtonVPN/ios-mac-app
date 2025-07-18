//
//  Created on 19/12/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Domain
import Foundation
import NetShield

/// Its sole purpose is to use this instead when ``UseConnectionFeature`` FF is enabled.
/// Once we fully migrate to Connection package, we can get rid of this NoOpVpnManager.
public final class NoOpVpnManager: VpnManagerProtocol {
    public var stateChanged: (() -> Void)?

    public var state: VpnState

    public var localAgentStateChanged: ((Bool?) -> Void)?

    public var isLocalAgentConnected: Bool?

    public var currentVpnProtocol: Domain.VpnProtocol?

    public var netShieldStats: NetShield.NetShieldModel

    init(
        stateChanged: (() -> Void)? = nil,
        state: VpnState = .invalid,
        localAgentStateChanged: ((Bool?) -> Void)? = nil,
        isLocalAgentConnected: Bool? = nil,
        currentVpnProtocol: Domain.VpnProtocol? = nil,
        netShieldStats: NetShield.NetShieldModel = .zero(enabled: false),
        prepareManagersTask: Task<Void, Never>? = nil
    ) {
        self.stateChanged = stateChanged
        self.state = state
        self.localAgentStateChanged = localAgentStateChanged
        self.isLocalAgentConnected = isLocalAgentConnected
        self.currentVpnProtocol = currentVpnProtocol
        self.netShieldStats = netShieldStats
        self.prepareManagersTask = prepareManagersTask
    }

    public func appBackgroundStateDidChange(isBackground _: Bool) {}

    public func isOnDemandEnabled(handler: @escaping (Bool) -> Void) {
        handler(false)
    }

    public func setOnDemand(_: Bool) {}

    public func disconnectAnyExistingConnectionAndPrepareToConnect(with _: VpnManagerConfiguration, completion _: @escaping () -> Void) {}

    public func disconnect(completion _: @escaping () -> Void) {}

    public func connectedDate() async -> Date? {
        .now
    }

    public func refreshState() {}

    public func refreshManagers() {}

    public func refreshManagers() async {}

    public func removeConfigurations(completionHandler _: (((any Error)?) -> Void)?) {}

    public func whenReady(queue: DispatchQueue, completion: @escaping () -> Void) {
        queue.async(execute: completion)
    }

    public var prepareManagersTask: Task<Void, Never>?

    public func set(vpnAccelerator _: Bool) {}

    public func set(netShieldType _: Domain.NetShieldType) {}

    public func set(natType _: Domain.NATType) {}

    public func set(safeMode _: Bool) {}

    public func set(portForwarding _: Bool) {}
}
