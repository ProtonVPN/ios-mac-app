//
//  Created on 2022-10-19.
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

import Foundation
import Timer
import VPNShared

public protocol ServerStatusRefreshDelegate: AnyObject {
    func reconnect(toAnyOf alternatives: [ServerStatusRequest.Logical])
}

public final class ServerStatusRefreshManager: RefreshManager {
    public weak var delegate: ServerStatusRefreshDelegate?

    private let apiService: ExtensionAPIService
    /// - Important: should set/get this value on `workQueue`.
    private var currentLogicalId: String?
    /// - Important: should set/get this value on `workQueue`.
    private var currentServerId: String?

    override public var timerRefreshInterval: TimeInterval {
        5 * 60 // 5 minutes
    }

    public init(apiService: ExtensionAPIService,
                timerFactory: TimerFactory) {
        let workQueue = DispatchQueue(label: "ch.protonvpn.extension.wireguard.server-status-refresh")

        self.apiService = apiService
        super.init(timerFactory: timerFactory, workQueue: workQueue)
    }

    public func updateConnectedIds(logicalId: String, serverId: String) {
        workQueue.async { [unowned self] in
            currentLogicalId = logicalId
            currentServerId = serverId
        }
    }

    override internal func work() async {
        log.warning("ServerStatusRefreshManager")
        guard let currentLogicalId, let currentServerId else {
            log.info("No connected server id set; not refreshing server status.", category: .connection)
            return
        }

        await apiService.refreshServerStatus(logicalId: currentLogicalId,
                                             refreshApiTokenIfNeeded: true) { [unowned self] result in
            workQueue.async { [unowned self] in
                switch result {
                case .success(let response):
                    // We could have disconnected since making the API request, so check if we're stopped.
                    guard case .running = state else {
                        log.info("Not reconnecting - refresh manager was already stopped", category: .connection)
                        return
                    }

                    if response.original.underMaintenance {
                        log.info("Server \(response.original.id) is in maintenance. Will reconnect to alternative server.", category: .connection)
                        self.delegate?.reconnect(toAnyOf: response.alternatives)
                    } else if let server = response.original.servers.first(where: { $0.id == currentServerId }) {
                        guard server.underMaintenance else {
                            log.info("Server \(currentServerId) is still live. No reconnection needed.", category: .connection)
                            return
                        }

                        log.info("Server ID \(currentServerId) in logical \(currentLogicalId) is in maintenance. Will reconnect to logical.", category: .connection)
                        self.delegate?.reconnect(toAnyOf: [response.original])
                    } else {
                        log.info("Server ID \(currentServerId) in logical \(currentLogicalId) has disappeared. Will reconnect to logical.", category: .connection)
                        self.delegate?.reconnect(toAnyOf: [response.original])
                    }
                case .failure(let error):
                    log.error("Couldn't refresh server state: \(error)", category: .connection)
                }
            }
        }
    }
}
