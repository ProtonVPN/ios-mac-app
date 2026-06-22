//
//  Created on 03/06/2024.
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

import Dependencies
import DependenciesMacros
import Domain
import IPCErgonomics
import IssueReporting

/// Thin client for the one tunnel-data signal that isn't a `RawChannel`: the payload-less fork-selector request
/// notification. The live tunnel-data channels (peer / stats / error / applied features) live on ``RawChannels``.
@DependencyClient
public struct LocalAgentClient {
    public internal(set) var listenToForkSelectorRequests: (_ callback: @escaping () -> Void) -> Void
}

extension LocalAgentClient: DependencyKey {
    public static let liveValue = LocalAgentClient { callback in
        IPCNotifications.observe(.extensionForkSelectorRequest, callback: callback)
    }
}

public extension DependencyValues {
    var localAgent: LocalAgentClient {
        get { self[LocalAgentClient.self] }
        set { self[LocalAgentClient.self] = newValue }
    }
}
