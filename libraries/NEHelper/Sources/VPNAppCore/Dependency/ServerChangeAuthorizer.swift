//
//  Created on 05/09/2024.
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

public struct ServerChangeAuthorizer {
    public private(set) var serverChangeAvailability: () -> ServerChangeAvailability
    private var registerServerChangeAtDate: (Date) -> Void

    public func registerServerChange(connectedAt connectionDate: Date) {
        registerServerChangeAtDate(connectionDate)
    }

    public enum ServerChangeAvailability: Equatable {
        case available
        case unavailable(until: Date, duration: TimeInterval, exhaustedSkips: Bool)
    }

    public init(serverChangeAvailability: @escaping () -> ServerChangeAvailability, registerServerChangeAtDate: @escaping (Date) -> Void) {
        self.serverChangeAvailability = serverChangeAvailability
        self.registerServerChangeAtDate = registerServerChangeAtDate
    }
}

extension DependencyValues {
    public var serverChangeAuthorizer: ServerChangeAuthorizer {
      get { self[ServerChangeAuthorizer.self] }
      set { self[ServerChangeAuthorizer.self] = newValue }
    }
}

extension ServerChangeAuthorizer: TestDependencyKey {
    public static let testValue = ServerChangeAuthorizer {
        .unavailable(until: .distantFuture, duration: .infinity, exhaustedSkips: true)
    } registerServerChangeAtDate: { date in

    }

    public static let previewValue = ServerChangeAuthorizer {
        .unavailable(until: Date().addingTimeInterval(60 * 60),
                     duration: 60 * 60 * 2,
                     exhaustedSkips: true)
    } registerServerChangeAtDate: { date in

    }

    public static let availableValue = ServerChangeAuthorizer {
        .available
    } registerServerChangeAtDate: { date in

    }
}
