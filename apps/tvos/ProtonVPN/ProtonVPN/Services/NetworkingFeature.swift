//
//  Created on 22/04/2024.
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

import ComposableArchitecture
import Dependencies

import ProtonCoreForceUpgrade
import ProtonCoreNetworking
import ProtonCoreServices

import CommonNetworking
import VPNShared
import VPNAppCore

// Should this be a different type of Reducer, e.g. higher order reducer?
// Should this also deal with forking child session, user codes authenticating selector, etc? maybe a child should do it?
// This could also EASILY live in the CommonNetworking (or SessionNetworking) module
struct NetworkingFeature: Reducer {
    enum State: Equatable {
        case unauthenticated // no session. Not to be confused with unauth session
        case acquiringSession // acquiring session
        case authenticated(CommonNetworking.Session) // auth or unauth session
    }

    enum Action {
        case startAcquiringSession
        case sessionFetched(SessionAcquiringResult)
        case sessionExpired
    }

    var body: some Reducer<State, Action> {
        @Dependency(\.networking) var networking
        Reduce { state, action in
            switch action {
            case .startAcquiringSession:
                return .run { send in await send(.sessionFetched(try networking.acquireSessionIfNeeded())) }

            case .sessionFetched(.sessionAlreadyPresent(let credentials)),
                .sessionFetched(.sessionFetchedAndAvailable(let credentials)):
                // Credentials already stored in keychain by Networking implementation in CommonNetworking
                state = .authenticated(.auth(uid: credentials.sessionID))
                return .none

            case .sessionFetched(.sessionUnavailableAndNotFetched):
                state = .unauthenticated
                return .none

            case .sessionExpired:
                // VPNAPPL-2180: `NetworkingDelegate` must send `.sessionExpired` action
                @Dependency(\.authKeychain) var authKeychain
                @Dependency(\.unauthKeychain) var unauthKeychain
                authKeychain.clear()
                unauthKeychain.clear()
                return .send(.startAcquiringSession)

            }
        }
    }
}
