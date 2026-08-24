//
//  Created on 17/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Collections
import ConnectionInventory
import Domain
import Foundation
import SwiftUI
import WidgetKit

struct ConnectWidgetEntry: TimelineEntry {
    let date: Date
    let connectionSpec: ConnectionSpec?
    let currentServer: Server?
    let protectionState: ProtectionState
    let recentServers: OrderedSet<RecentConnection>

    enum ProtectionState: Equatable {
        case signedOut
        case protected
        case unprotected
        case protecting
    }

    static var loggedOutEntry: Self {
        ConnectWidgetEntry(
            date: .now,
            connectionSpec: nil,
            currentServer: nil,
            protectionState: .signedOut,
            recentServers: []
        )
    }
}

extension ConnectWidgetEntry {
    var currentLocation: ConnectionSpec.Location? {
        switch protectionState {
        case .protected, .protecting:
            // For `random` connections, when connecting/connected, we show the resolved server.
            if connectionSpec?.location.selectionSpec == .random, let currentServer {
                return CityStateConnectionSpecFactory.serverLocation(for: currentServer.logical)
                    .applying(RecentConnection.ServerDisplay(logical: currentServer.logical))
            }
        case .signedOut, .unprotected:
            break
        }
        return connectionSpec?.location
    }
}
