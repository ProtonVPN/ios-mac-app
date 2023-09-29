//
//  Created on 31/08/2023.
//
//  Copyright (c) 2023 Proton AG
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
    public var serverChangeAvailability: () -> ServerChangeAvailability
    private var registerServerChangeAtDate: (Date) -> Void

    public func registerServerChange(connectedAt connectionDate: Date) {
        registerServerChangeAtDate(connectionDate)
    }

    public enum ServerChangeAvailability: Equatable {
        case available
        case unavailable(until: Date, duration: TimeInterval, exhaustedSkips: Bool)
    }
}

extension ServerChangeAuthorizer: DependencyKey {
    public static var liveValue: Self = {
        let authorizer = ServerChangeAuthorizerImplementation()
        return ServerChangeAuthorizer(
            serverChangeAvailability: authorizer.serverChangeAvailability,
            registerServerChangeAtDate: authorizer.registerServerChange
        )
    }()

    #if DEBUG
    public static let testValue: ServerChangeAuthorizer = liveValue
    #endif
}

extension DependencyValues {
    public var serverChangeAuthorizer: ServerChangeAuthorizer {
      get { self[ServerChangeAuthorizer.self] }
      set { self[ServerChangeAuthorizer.self] = newValue }
    }
}

public enum ServerChangeViewState {
    case available
    case unavailable(duration: String)

    public static func from(state: ServerChangeAuthorizer.ServerChangeAvailability) -> Self {
        switch state {
        case .available:
            return .available

        case let .unavailable(until, _, _):
            @Dependency(\.date) var date
            let formattedDuration = until.timeIntervalSince(date.now)
                .asColonSeparatedString(maxUnit: .hour, minUnit: .minute)
            return .unavailable(duration: formattedDuration)
        }
    }

    /// Little helper to use more elegant code
    public var isUnavailable: Bool {
        switch self {
        case .unavailable:
            return true
        default:
            return false
        }
    }
}
