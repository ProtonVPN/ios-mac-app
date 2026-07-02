//
//  Created on 27/06/2026.
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

public extension SharedReaderKey where Self == StreamReaderKey<ExtensionError?> {
    /// The extension's most-recent reported error from the live `localAgentError` channel, paired with the request id
    /// it pertains to (if any exists).
    static var extensionError: Self {
        StreamReaderKey(
            read: {
                @Dependency(\.extensionIPC) var extensionIPC
                return extensionIPC.currentExtensionError()
            },
            updates: {
                @Dependency(\.extensionIPC) var extensionIPC
                return extensionIPC.observeError()
            }
        )
    }
}
