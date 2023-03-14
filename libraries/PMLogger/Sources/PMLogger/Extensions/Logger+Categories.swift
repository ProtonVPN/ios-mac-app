//
//  Created on 2021-11-19.
//
//  Copyright (c) 2021 Proton AG
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
import Logging

extension Logger {
    
    public enum Category: String {
        case connection = "conn"
        case connectionConnect = "conn.connect"
        case connectionDisconnect = "conn.disconnect"
        case localAgent = "local_agent"
        case ui
        case user
        case userCert = "user_cert"
        case userPlan = "user_plan"
        case api
        case net
        case `protocol`
        case app
        case appUpdate = "app.update"
        case os
        case settings
        case keychain = "secure_store"
        case iap = "in_app_purchase"
        case persistence
        // Custom ios (please add to confluence)
        case sysex // System Extension
        case review
        case core
        case telemetry
    }

    public enum Event: String {
        case current
        case stateChange = "state_change"
        case error
        case trigger
        case scan
        case scanFailed = "scan_failed"
        case scanResult = "scan_result"
        case start
        case connected
        case serverSelected = "server_selected"
        case switchFailed = "switch_failed"
        case log
        case status
        case connect
        case disconnect
        case refresh
        case revoked
        case newCertificate = "new_cert"
        case refreshError = "refresh_error"
        case scheduleRefresh = "schedule_refresh"
        case change
        case maxSessionsReached = "max_sessions_reached"
        case request
        case response
        case networkUnavailable = "network_unavailable"
        case networkChanged = "network_changed"
        case processStart = "process_start"
        case crash
        case updateCheck = "update_check"
        case info
    }
}
