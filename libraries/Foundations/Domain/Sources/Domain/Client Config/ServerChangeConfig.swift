//
//  Created on 30/07/2026 by Max Kupetskyi.
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

import Ergonomics
import Foundation

/// Encapsulates the three server change config properties.
///
/// - Note: The response for `vpn/v2/clientconfig` does not encapsulate these properties, so it should be decoded directly
/// without using a container.
public struct ServerChangeConfig: Codable, DefaultableProperty, Sendable {
    public let changeServerAttemptLimit: Int
    public let changeServerShortDelayInSeconds: Int
    public let changeServerLongDelayInSeconds: Int

    public init(
        changeServerAttemptLimit: Int,
        changeServerShortDelayInSeconds: Int,
        changeServerLongDelayInSeconds: Int
    ) {
        self.changeServerAttemptLimit = changeServerAttemptLimit
        self.changeServerShortDelayInSeconds = changeServerShortDelayInSeconds
        self.changeServerLongDelayInSeconds = changeServerLongDelayInSeconds
    }

    public init() {
        self.init(
            changeServerAttemptLimit: 4,
            changeServerShortDelayInSeconds: 90,
            changeServerLongDelayInSeconds: 1200
        )
    }
}
