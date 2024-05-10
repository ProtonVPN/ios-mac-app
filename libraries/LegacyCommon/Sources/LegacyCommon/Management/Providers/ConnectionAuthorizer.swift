//
//  Created on 30/08/2023.
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
import Modals

/// Responsible for authorizing or denying connection requests based on the user's plan and available features
public struct ConnectionAuthorizer {
    public var authorize: (ConnectionRequest) -> ConnectionAuthorizationResult

    public func authorize(request: ConnectionRequest) -> ConnectionAuthorizationResult { authorize(request) }
}

public typealias ConnectionAuthorizationResult = Result<None, ConnectionAuthorizationFailureReason>

public enum ConnectionAuthorizationFailureReason: Error, Equatable {
    case serverChangeUnavailable(until: Date, duration: TimeInterval, exhaustedSkips: Bool)
    case specificCountryUnavailable(countryCode: String)
}

extension ConnectionAuthorizer: DependencyKey {
    public static var liveValue: ConnectionAuthorizer = ConnectionAuthorizer(
        authorize: { request in
            @Dependency(\.serverChangeAuthorizer) var serverChangeAuthorizer

            switch request.connectionType {
            case .fastest:
                return .success

            case .random:
                switch serverChangeAuthorizer.serverChangeAvailability() {
                case .available:
                    return .success
                case let .unavailable(date, duration, exhaustedSkips):
                    return .failure(.serverChangeUnavailable(
                        until: date,
                        duration: duration,
                        exhaustedSkips: exhaustedSkips
                    ))
                }
            case .city(let countryCode, _), .country(let countryCode, _):
                return .failure(.specificCountryUnavailable(countryCode: countryCode))
            }
        }
    )

    #if DEBUG
    public static var testValue: ConnectionAuthorizer = liveValue
    #endif
}

extension DependencyValues {
    public var connectionAuthorizer: ConnectionAuthorizer {
      get { self[ConnectionAuthorizer.self] }
      set { self[ConnectionAuthorizer.self] = newValue }
    }
}
