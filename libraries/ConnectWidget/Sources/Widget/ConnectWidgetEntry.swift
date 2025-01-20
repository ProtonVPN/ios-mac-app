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

import Foundation
import WidgetKit
import SwiftUI
import Domain

// Still WIP
public struct ConnectWidgetEntry: TimelineEntry {
    public let date: Date
    public let connectionSpec: ConnectionSpec?
    public let protectionState: ProtectionState
    public let recentServers: [RecentConnection]

    public enum ProtectionState: Equatable {
        case signedOut
        case protected
        case unprotected
        case protecting
    }
}
