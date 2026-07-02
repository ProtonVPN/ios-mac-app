//
//  Created on 25/06/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Domain
import ExtensionSync
import Foundation
import Sharing

public extension SharedReaderKey where Self == StreamReaderKey<(state: ExtensionState, requestId: UUID?)> {
    static var extensionState: Self {
        StreamReaderKey(
            read: {
                @Dependency(\.extensionIPC) var extensionIPC
                return extensionIPC.currentExtensionState()
            },
            updates: {
                @Dependency(\.extensionIPC) var extensionIPC
                return extensionIPC.observeExtensionState()
            }
        )
    }
}
