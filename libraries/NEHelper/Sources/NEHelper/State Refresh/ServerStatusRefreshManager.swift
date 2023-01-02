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

public final class ServerStatusRefreshManager: RefreshManager {
    public typealias ServerStatusChangeCallback = ([ServerStatusRequest.Logical]) -> Void

    private let apiService: ExtensionAPIService
    /// - Important: should set/get this value on `workQueue`.
    private var currentServerId: String?
    private let serverStatusChangeCallback: ServerStatusChangeCallback

    override public var timerRefreshInterval: TimeInterval {
        5 * 60 // 5 minutes
    }

    public init(apiService: ExtensionAPIService,
                timerFactory: TimerFactory,
                serverStatusChangeCallback: @escaping ServerStatusChangeCallback) {
        let workQueue = DispatchQueue(label: "ch.protonvpn.extension.wireguard.server-status-refresh")

        self.apiService = apiService
        self.serverStatusChangeCallback = serverStatusChangeCallback

        super.init(timerFactory: timerFactory, workQueue: workQueue)
    }

    public func updateConnectedServerId(_ serverId: String) {
        workQueue.async { [unowned self] in
            currentServerId = serverId
        }
    }

    override internal func work() {
        log.warning("ServerStatusRefreshManager")
        guard let serverId = currentServerId else {
            log.info("No connected server id set; not refreshing server status.", category: .connection)
            return
        }

        apiService.refreshServerStatus(logicalId: serverId,
                                       refreshApiTokenIfNeeded: true) { [unowned self] result in
            workQueue.async { [unowned self] in
                switch result {
                case .success(let response):
                    guard response.original.status == 0 else {
                        log.info("Server is not in maintenance. No reconnection needed.", category: .connection)
                        return
                    }

                    log.info("Server \(response.original.id) is in maintenance. Will reconnect to alternative server.", category: .connection)

                    // We could have disconnected since making the API request, so check if we're stopped.
                    guard case .running = state else {
                        log.info("Not reconnecting - refresh manager was already stopped", category: .connection)
                        return
                    }

                    serverStatusChangeCallback(response.alternatives)
                    
                case .failure(let error):
                    log.error("Couldn't refresh server state: \(error)", category: .connection)
                }
            }
        }
    }
}
