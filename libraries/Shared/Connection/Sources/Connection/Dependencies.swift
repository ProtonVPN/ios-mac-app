//
//  Created on 13/06/2024.
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

import Foundation
import Dependencies
import struct ConnectionFoundations.LogicalServerInfo
import struct Domain.Server

/// We need to fetch full server information to determine e.g. what country the extension is connected to.
/// The server is identified by its logical and server IDs.
///
/// We could avoid defining this dependency and instead have `Connection` depend on `Persistence`, but it's preferable
/// to not depend on packages in the same layer.
public struct ServerIdentifier: TestDependencyKey {
    var fullServerInfo: (LogicalServerInfo) -> Server?

    public init(fullServerInfo: @escaping (LogicalServerInfo) -> Server?) {
        self.fullServerInfo = fullServerInfo
    }

    public static let testValue = ServerIdentifier(fullServerInfo: unimplemented())
}

extension DependencyValues {
    public var serverIdentifier: ServerIdentifier {
        get { self[ServerIdentifier.self] }
        set { self[ServerIdentifier.self] = newValue }
    }
}
