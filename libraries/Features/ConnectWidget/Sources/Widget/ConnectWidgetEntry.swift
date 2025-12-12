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

import Domain
import Foundation
import SwiftUI
import WidgetKit

public struct ConnectWidgetEntry: TimelineEntry {
    public let date: Date
    public let connectionSpec: ConnectionSpec?
    public let currentServer: Server?
    public let protectionState: ProtectionState
    public let recentServers: [RecentConnection]

    public enum ProtectionState: Equatable {
        case signedOut
        case protected
        case unprotected
        case protecting
    }
}

extension ConnectWidgetEntry {
    var currentLocation: ConnectionSpec.Location? {
        switch protectionState {
        case .protected, .protecting:
            // For `random` connections, when connecting/connected, we show the resolved server.
            if connectionSpec?.location.selectionSpec == .random, let currentServer {
                return ConnectionSpec.Location.exact(
                    currentServer.logical.tier.isPaidTier ? .paid : .free,
                    logicalID: currentServer.logical.id,
                    number: currentServer.logical.serverNameComponents.sequence,
                    subregion: currentServer.logical.city,
                    regionCode: currentServer.logical.exitCountryCode
                )
            }
        case .signedOut, .unprotected:
            break
        }
        return connectionSpec?.location
    }
}
